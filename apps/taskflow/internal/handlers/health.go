package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/reference-platform/taskflow/internal/database"
	"github.com/reference-platform/taskflow/internal/queue"
)

// HealthHandler handles health check endpoints
type HealthHandler struct {
	db     *database.DB
	queue  *queue.Queue
	logger *slog.Logger
}

// NewHealthHandler creates a new health handler
func NewHealthHandler(db *database.DB, queue *queue.Queue, logger *slog.Logger) *HealthHandler {
	return &HealthHandler{
		db:     db,
		queue:  queue,
		logger: logger,
	}
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status string            `json:"status"`
	Checks map[string]string `json:"checks,omitempty"`
}

// Health returns a basic health check (liveness probe)
func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(HealthResponse{
		Status: "healthy",
	})
}

// Ready returns a readiness check (checks dependencies)
func (h *HealthHandler) Ready(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	checks := make(map[string]string)
	allHealthy := true

	// Check database
	if err := h.db.HealthCheck(ctx); err != nil {
		checks["database"] = "unhealthy: " + err.Error()
		allHealthy = false
		h.logger.Error("Database health check failed", "error", err)
	} else {
		checks["database"] = "healthy"
	}

	// Check Redis queue
	if err := h.queue.HealthCheck(ctx); err != nil {
		checks["queue"] = "unhealthy: " + err.Error()
		allHealthy = false
		h.logger.Error("Queue health check failed", "error", err)
	} else {
		checks["queue"] = "healthy"
	}

	w.Header().Set("Content-Type", "application/json")

	if allHealthy {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(HealthResponse{
			Status: "ready",
			Checks: checks,
		})
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(HealthResponse{
			Status: "not ready",
			Checks: checks,
		})
	}
}
