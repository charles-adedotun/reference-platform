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
	"github.com/reference-platform/taskflow/internal/models"
	"github.com/reference-platform/taskflow/internal/queue"
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
	logger := logging.NewLogger(cfg.ServiceName + "-worker")
	logger.Info("Starting TaskFlow worker",
		"service", cfg.ServiceName,
	)

	// Initialize OpenTelemetry
	ctx := context.Background()
	shutdownTracer, err := telemetry.InitTracer(ctx, cfg.ServiceName+"-worker", cfg.OTELEndpoint, logger)
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

	// Initialize queue
	q, err := queue.NewQueue(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB, logger)
	if err != nil {
		logger.Error("Failed to connect to Redis", "error", err)
		os.Exit(1)
	}
	defer q.Close()

	// Create worker
	worker := NewWorker(db, q, logger)

	// Setup signal handling
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// Run worker
	logger.Info("Worker started, waiting for tasks...")
	worker.Run(shutdown)
	logger.Info("Worker stopped gracefully")
}

// Worker processes tasks from the queue
type Worker struct {
	db     *database.DB
	queue  *queue.Queue
	logger *slog.Logger
}

// NewWorker creates a new worker
func NewWorker(db *database.DB, queue *queue.Queue, logger *slog.Logger) *Worker {
	return &Worker{
		db:     db,
		queue:  queue,
		logger: logger,
	}
}

// Run starts the worker loop
func (w *Worker) Run(shutdown <-chan os.Signal) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown in a separate goroutine
	go func() {
		<-shutdown
		w.logger.Info("Shutdown signal received, stopping worker...")
		cancel()
	}()

	for {
		select {
		case <-ctx.Done():
			w.logger.Info("Context cancelled, stopping worker...")
			return

		default:
			// Dequeue task with timeout
			dequeueCtx, dequeueCancel := context.WithTimeout(ctx, 5*time.Second)
			msg, err := w.queue.Dequeue(dequeueCtx, 5*time.Second)
			dequeueCancel()

			if err != nil {
				// Check if context was cancelled (graceful shutdown)
				if ctx.Err() != nil {
					w.logger.Info("Stopping worker due to context cancellation")
					return
				}
				w.logger.Error("Failed to dequeue task", "error", err)
				time.Sleep(1 * time.Second)
				continue
			}

			// No task available
			if msg == nil {
				continue
			}

			// Process task
			w.processTask(ctx, msg)
		}
	}
}

// processTask processes a single task
func (w *Worker) processTask(ctx context.Context, msg *queue.TaskMessage) {
	tracer := telemetry.GetTracer("taskflow-worker")
	ctx, span := tracer.Start(ctx, "ProcessTask")
	defer span.End()

	span.SetAttributes(
		attribute.String("task.id", msg.TaskID),
		attribute.String("task.action", msg.Action),
	)

	w.logger.InfoContext(ctx, "Processing task",
		"task_id", msg.TaskID,
		"action", msg.Action,
	)

	// Simulate work
	processingTime := time.Duration(500+time.Now().UnixNano()%1500) * time.Millisecond
	time.Sleep(processingTime)

	// Update task status to completed
	status := models.StatusCompleted
	_, err := w.db.UpdateTask(ctx, msg.TaskID, &models.UpdateTaskRequest{
		Status: &status,
	})

	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to update task")
		w.logger.ErrorContext(ctx, "Failed to update task status",
			"task_id", msg.TaskID,
			"error", err,
		)
		return
	}

	span.SetAttributes(attribute.Int64("task.processing_time_ms", processingTime.Milliseconds()))
	span.SetStatus(codes.Ok, "Task processed successfully")

	w.logger.InfoContext(ctx, "Task processed successfully",
		"task_id", msg.TaskID,
		"processing_time_ms", processingTime.Milliseconds(),
	)
}
