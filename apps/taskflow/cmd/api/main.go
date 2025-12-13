package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/httprate"
	"github.com/reference-platform/taskflow/internal/config"
	"github.com/reference-platform/taskflow/internal/database"
	"github.com/reference-platform/taskflow/internal/handlers"
	"github.com/reference-platform/taskflow/internal/queue"
	"github.com/reference-platform/taskflow/pkg/logging"
	"github.com/reference-platform/taskflow/pkg/telemetry"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	logger := logging.NewLogger(cfg.ServiceName + "-api")
	logger.Info("Starting TaskFlow API server",
		"port", cfg.ServerPort,
		"service", cfg.ServiceName,
	)

	// Initialize OpenTelemetry
	ctx := context.Background()
	shutdownTracer, err := telemetry.InitTracer(ctx, cfg.ServiceName+"-api", cfg.OTELEndpoint, logger)
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
	defer func() {
		if err := q.Close(); err != nil {
			logger.Error("Failed to close queue connection", "error", err)
		}
	}()

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(db, q, logger)
	taskHandler := handlers.NewTaskHandler(db, q, logger)
	transactionHandler := handlers.NewTransactionHandler(db, q, logger)

	// Setup router
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(httprate.LimitByIP(100, time.Minute))

	// Health check routes
	r.Get("/health", healthHandler.Health)
	r.Get("/ready", healthHandler.Ready)

	// API routes
	r.Route("/api/v1", func(r chi.Router) {
		// Task routes
		r.Post("/tasks", taskHandler.CreateTask)
		r.Get("/tasks", taskHandler.ListTasks)
		r.Get("/tasks/{id}", taskHandler.GetTask)
		r.Put("/tasks/{id}", taskHandler.UpdateTask)
		r.Delete("/tasks/{id}", taskHandler.DeleteTask)

		// Synthetic transaction route
		r.Post("/transaction", transactionHandler.SyntheticTransaction)
	})

	// Create HTTP server
	// Note: Server timeouts must be longer than middleware timeout (60s)
	// to allow proper timeout responses to clients
	server := &http.Server{
		Addr:         ":" + cfg.ServerPort,
		Handler:      r,
		ReadTimeout:  70 * time.Second,
		WriteTimeout: 70 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in a goroutine
	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("HTTP server listening", "addr", server.Addr)
		serverErrors <- server.ListenAndServe()
	}()

	// Wait for interrupt signal or server error
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		logger.Error("Server error", "error", err)
		os.Exit(1)

	case sig := <-shutdown:
		logger.Info("Shutdown signal received", "signal", sig)

		// Create context with timeout for shutdown
		ctx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()

		// Attempt graceful shutdown
		if err := server.Shutdown(ctx); err != nil {
			logger.Error("Graceful shutdown failed", "error", err)
			if err := server.Close(); err != nil {
				logger.Error("Server close failed", "error", err)
			}
			os.Exit(1)
		}

		logger.Info("Server stopped gracefully")
	}
}
