package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/reference-platform/taskflow/internal/config"
	"github.com/reference-platform/taskflow/internal/database"
	"github.com/reference-platform/taskflow/pkg/logging"
	"github.com/reference-platform/taskflow/pkg/telemetry"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	logger := logging.NewLogger(cfg.ServiceName + "-cron")
	logger.Info("Starting TaskFlow cron job",
		"service", cfg.ServiceName,
	)

	// Initialize OpenTelemetry
	ctx := context.Background()
	shutdownTracer, err := telemetry.InitTracer(ctx, cfg.ServiceName+"-cron", cfg.OTELEndpoint, cfg.OTELInsecure, logger)
	if err != nil {
		logger.Error("Failed to initialize tracer", "error", err)
		os.Exit(1)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := shutdownTracer(ctx); err != nil {
			logger.Error("Failed to shutdown tracer", "error", err)
		}
	}()

	// Initialize database
	db, err := database.NewDB(ctx, cfg.DatabaseURL, logger)
	if err != nil {
		logger.Error("Failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	// Create cleanup job
	job := NewCleanupJob(db, logger)

	// Setup signal handling
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// Run cron job
	logger.Info("Cron job started")
	job.Run(shutdown)
	logger.Info("Cron job stopped gracefully")
}

// CleanupJob handles periodic cleanup of old tasks
type CleanupJob struct {
	db        *database.DB
	logger    *slog.Logger
	interval  time.Duration
	retention time.Duration
}

// NewCleanupJob creates a new cleanup job
func NewCleanupJob(db *database.DB, logger *slog.Logger) *CleanupJob {
	return &CleanupJob{
		db:        db,
		logger:    logger,
		interval:  1 * time.Hour,      // Run every hour
		retention: 7 * 24 * time.Hour, // Keep tasks for 7 days
	}
}

// Run starts the cleanup job loop
func (j *CleanupJob) Run(shutdown <-chan os.Signal) {
	ctx := context.Background()

	// Run immediately on startup
	j.cleanup(ctx)

	// Create ticker for periodic execution
	ticker := time.NewTicker(j.interval)
	defer ticker.Stop()

	for {
		select {
		case <-shutdown:
			j.logger.Info("Shutdown signal received, stopping cron job...")
			return

		case <-ticker.C:
			j.cleanup(ctx)
		}
	}
}

// cleanup performs the cleanup operation
func (j *CleanupJob) cleanup(ctx context.Context) {
	tracer := telemetry.GetTracer("taskflow-cron")
	ctx, span := tracer.Start(ctx, "CleanupOldTasks")
	defer span.End()

	j.logger.InfoContext(ctx, "Starting cleanup of old completed tasks",
		"retention_hours", j.retention.Hours(),
	)

	startTime := time.Now()
	deleted, err := j.db.DeleteOldCompletedTasks(ctx, j.retention)
	duration := time.Since(startTime)

	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Cleanup failed")
		j.logger.ErrorContext(ctx, "Failed to cleanup old tasks",
			"error", err,
			"duration_ms", duration.Milliseconds(),
		)
		return
	}

	span.SetAttributes(
		attribute.Int64("tasks.deleted", deleted),
		attribute.Int64("cleanup.duration_ms", duration.Milliseconds()),
	)
	span.SetStatus(codes.Ok, "Cleanup completed")

	j.logger.InfoContext(ctx, "Cleanup completed",
		"deleted_count", deleted,
		"duration_ms", duration.Milliseconds(),
	)
}
