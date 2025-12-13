package handlers

import (
	"context"
	"encoding/json"
	"log/slog"
	"math/rand"
	"net/http"
	"time"

	"github.com/reference-platform/taskflow/internal/database"
	"github.com/reference-platform/taskflow/internal/models"
	"github.com/reference-platform/taskflow/internal/queue"
	"github.com/reference-platform/taskflow/pkg/telemetry"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// TransactionHandler handles synthetic transaction monitoring
type TransactionHandler struct {
	db     *database.DB
	queue  *queue.Queue
	logger *slog.Logger
}

// NewTransactionHandler creates a new transaction handler
func NewTransactionHandler(db *database.DB, queue *queue.Queue, logger *slog.Logger) *TransactionHandler {
	return &TransactionHandler{
		db:     db,
		queue:  queue,
		logger: logger,
	}
}

// TransactionResponse represents the response from a synthetic transaction
type TransactionResponse struct {
	TransactionID string                 `json:"transaction_id"`
	Status        string                 `json:"status"`
	Duration      string                 `json:"duration"`
	Steps         []TransactionStep      `json:"steps"`
	Metadata      map[string]interface{} `json:"metadata"`
}

// TransactionStep represents a step in the synthetic transaction
type TransactionStep struct {
	Name     string `json:"name"`
	Duration string `json:"duration"`
	Status   string `json:"status"`
}

// SyntheticTransaction handles POST /api/v1/transaction
// This endpoint simulates a complex business transaction for monitoring purposes
func (h *TransactionHandler) SyntheticTransaction(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "SyntheticTransaction")
	defer span.End()

	startTime := time.Now()
	steps := []TransactionStep{}

	// Step 1: Create a task
	createStart := time.Now()
	task, err := h.createSyntheticTask(ctx)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to create synthetic task")
		h.logger.ErrorContext(ctx, "Synthetic transaction failed at create step", "error", err)
		h.respondError(w, http.StatusInternalServerError, "Transaction failed: "+err.Error())
		return
	}
	steps = append(steps, TransactionStep{
		Name:     "create_task",
		Duration: time.Since(createStart).String(),
		Status:   "success",
	})

	span.SetAttributes(attribute.String("transaction.task_id", task.ID))

	// Step 2: Enqueue task
	enqueueStart := time.Now()
	if err := h.queue.Enqueue(ctx, task.ID, "synthetic"); err != nil {
		h.logger.WarnContext(ctx, "Failed to enqueue synthetic task", "task_id", task.ID, "error", err)
		steps = append(steps, TransactionStep{
			Name:     "enqueue_task",
			Duration: time.Since(enqueueStart).String(),
			Status:   "failed",
		})
	} else {
		steps = append(steps, TransactionStep{
			Name:     "enqueue_task",
			Duration: time.Since(enqueueStart).String(),
			Status:   "success",
		})
	}

	// Step 3: Retrieve task
	getStart := time.Now()
	retrievedTask, err := h.db.GetTask(ctx, task.ID)
	if err != nil {
		span.RecordError(err)
		h.logger.ErrorContext(ctx, "Synthetic transaction failed at get step", "error", err)
		steps = append(steps, TransactionStep{
			Name:     "retrieve_task",
			Duration: time.Since(getStart).String(),
			Status:   "failed",
		})
	} else {
		steps = append(steps, TransactionStep{
			Name:     "retrieve_task",
			Duration: time.Since(getStart).String(),
			Status:   "success",
		})
	}

	// Step 4: Update task status
	updateStart := time.Now()
	status := models.StatusProcessing
	_, err = h.db.UpdateTask(ctx, task.ID, &models.UpdateTaskRequest{
		Status: &status,
	})
	if err != nil {
		span.RecordError(err)
		h.logger.ErrorContext(ctx, "Synthetic transaction failed at update step", "error", err)
		steps = append(steps, TransactionStep{
			Name:     "update_task",
			Duration: time.Since(updateStart).String(),
			Status:   "failed",
		})
	} else {
		steps = append(steps, TransactionStep{
			Name:     "update_task",
			Duration: time.Since(updateStart).String(),
			Status:   "success",
		})
	}

	// Step 5: Check queue length
	queueStart := time.Now()
	queueLen, err := h.queue.QueueLength(ctx)
	if err != nil {
		h.logger.WarnContext(ctx, "Failed to check queue length", "error", err)
		steps = append(steps, TransactionStep{
			Name:     "check_queue",
			Duration: time.Since(queueStart).String(),
			Status:   "failed",
		})
	} else {
		steps = append(steps, TransactionStep{
			Name:     "check_queue",
			Duration: time.Since(queueStart).String(),
			Status:   "success",
		})
	}

	totalDuration := time.Since(startTime)

	span.SetAttributes(
		attribute.Int64("transaction.duration_ms", totalDuration.Milliseconds()),
		attribute.Int("transaction.steps", len(steps)),
	)
	span.SetStatus(codes.Ok, "Synthetic transaction completed")

	response := TransactionResponse{
		TransactionID: task.ID,
		Status:        "completed",
		Duration:      totalDuration.String(),
		Steps:         steps,
		Metadata: map[string]interface{}{
			"task_id":      task.ID,
			"task_title":   retrievedTask.Title,
			"task_status":  retrievedTask.Status,
			"queue_length": queueLen,
			"timestamp":    time.Now().UTC(),
		},
	}

	h.logger.InfoContext(ctx, "Synthetic transaction completed",
		"transaction_id", task.ID,
		"duration_ms", totalDuration.Milliseconds(),
		"steps", len(steps),
	)

	h.respondJSON(w, http.StatusOK, response)
}

// createSyntheticTask creates a task for synthetic monitoring
func (h *TransactionHandler) createSyntheticTask(ctx context.Context) (*models.Task, error) {
	req := &models.CreateTaskRequest{
		Title:       "Synthetic monitoring task " + time.Now().Format(time.RFC3339),
		Description: "This task is created for synthetic monitoring purposes",
		Priority:    rand.Intn(5),
	}

	return h.db.CreateTask(ctx, req)
}

// respondJSON sends a JSON response
func (h *TransactionHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.logger.Error("Failed to encode response", "error", err)
	}
}

// respondError sends an error response
func (h *TransactionHandler) respondError(w http.ResponseWriter, status int, message string) {
	h.respondJSON(w, status, ErrorResponse{Error: message})
}
