package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/reference-platform/taskflow/internal/database"
	"github.com/reference-platform/taskflow/internal/models"
	"github.com/reference-platform/taskflow/internal/queue"
	"github.com/reference-platform/taskflow/pkg/telemetry"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// TaskHandler handles task-related HTTP requests
type TaskHandler struct {
	db     *database.DB
	queue  *queue.Queue
	logger *slog.Logger
}

// NewTaskHandler creates a new task handler
func NewTaskHandler(db *database.DB, queue *queue.Queue, logger *slog.Logger) *TaskHandler {
	return &TaskHandler{
		db:     db,
		queue:  queue,
		logger: logger,
	}
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error string `json:"error"`
}

// CreateTask handles POST /tasks
func (h *TaskHandler) CreateTask(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "CreateTask")
	defer span.End()

	var req models.CreateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Invalid request body")
		h.respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := req.Validate(); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		h.respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	span.SetAttributes(
		attribute.String("task.title", req.Title),
		attribute.Int("task.priority", req.Priority),
	)

	task, err := h.db.CreateTask(ctx, &req)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to create task")
		h.logger.ErrorContext(ctx, "Failed to create task", "error", err)
		h.respondError(w, http.StatusInternalServerError, "Failed to create task")
		return
	}

	// Enqueue task for processing
	if err := h.queue.Enqueue(ctx, task.ID, "process"); err != nil {
		h.logger.ErrorContext(ctx, "Failed to enqueue task", "task_id", task.ID, "error", err)
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to enqueue task")
		h.respondError(w, http.StatusServiceUnavailable, "Task created but queue unavailable, please retry")
		return
	}

	span.SetAttributes(attribute.String("task.id", task.ID))
	span.SetStatus(codes.Ok, "Task created successfully")

	h.logger.InfoContext(ctx, "Task created",
		"task_id", task.ID,
		"title", task.Title,
	)

	h.respondJSON(w, http.StatusCreated, task)
}

// GetTask handles GET /tasks/{id}
func (h *TaskHandler) GetTask(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "GetTask")
	defer span.End()

	taskID := chi.URLParam(r, "id")
	span.SetAttributes(attribute.String("task.id", taskID))

	task, err := h.db.GetTask(ctx, taskID)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Task not found")
		h.logger.ErrorContext(ctx, "Failed to get task", "task_id", taskID, "error", err)
		h.respondError(w, http.StatusNotFound, "Task not found")
		return
	}

	span.SetStatus(codes.Ok, "Task retrieved successfully")
	h.respondJSON(w, http.StatusOK, task)
}

// ListTasks handles GET /tasks
func (h *TaskHandler) ListTasks(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "ListTasks")
	defer span.End()

	tasks, err := h.db.ListTasks(ctx)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to list tasks")
		h.logger.ErrorContext(ctx, "Failed to list tasks", "error", err)
		h.respondError(w, http.StatusInternalServerError, "Failed to list tasks")
		return
	}

	span.SetAttributes(attribute.Int("tasks.count", len(tasks)))
	span.SetStatus(codes.Ok, "Tasks listed successfully")

	h.respondJSON(w, http.StatusOK, tasks)
}

// UpdateTask handles PUT /tasks/{id}
func (h *TaskHandler) UpdateTask(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "UpdateTask")
	defer span.End()

	taskID := chi.URLParam(r, "id")
	span.SetAttributes(attribute.String("task.id", taskID))

	var req models.UpdateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Invalid request body")
		h.respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := req.Validate(); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		h.respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	task, err := h.db.UpdateTask(ctx, taskID, &req)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to update task")
		h.logger.ErrorContext(ctx, "Failed to update task", "task_id", taskID, "error", err)
		h.respondError(w, http.StatusNotFound, "Task not found")
		return
	}

	span.SetStatus(codes.Ok, "Task updated successfully")

	h.logger.InfoContext(ctx, "Task updated",
		"task_id", task.ID,
		"status", task.Status,
	)

	h.respondJSON(w, http.StatusOK, task)
}

// DeleteTask handles DELETE /tasks/{id}
func (h *TaskHandler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tracer := telemetry.GetTracer("taskflow-api")
	ctx, span := tracer.Start(ctx, "DeleteTask")
	defer span.End()

	taskID := chi.URLParam(r, "id")
	span.SetAttributes(attribute.String("task.id", taskID))

	if err := h.db.DeleteTask(ctx, taskID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Failed to delete task")
		h.logger.ErrorContext(ctx, "Failed to delete task", "task_id", taskID, "error", err)
		h.respondError(w, http.StatusNotFound, "Task not found")
		return
	}

	span.SetStatus(codes.Ok, "Task deleted successfully")

	h.logger.InfoContext(ctx, "Task deleted", "task_id", taskID)

	w.WriteHeader(http.StatusNoContent)
}

// respondJSON sends a JSON response
func (h *TaskHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.logger.Error("Failed to encode response", "error", err)
	}
}

// respondError sends an error response
func (h *TaskHandler) respondError(w http.ResponseWriter, status int, message string) {
	h.respondJSON(w, status, ErrorResponse{Error: message})
}
