package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/reference-platform/taskflow/internal/models"
)

func TestTaskHandler_CreateTask_ValidationFailure(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := NewTaskHandler(nil, nil, logger)

	body, _ := json.Marshal(models.CreateTaskRequest{Title: "", Priority: 99})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	h.CreateTask(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("CreateTask invalid input status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestTaskHandler_CreateTask_InvalidJSON(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := NewTaskHandler(nil, nil, logger)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/tasks", strings.NewReader("{bad-json"))
	rec := httptest.NewRecorder()

	h.CreateTask(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("CreateTask invalid JSON status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestTaskHandler_UpdateTask_ValidationFailure(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := NewTaskHandler(nil, nil, logger)

	badStatus := "invalid_status"
	body, _ := json.Marshal(models.UpdateTaskRequest{Status: &badStatus})
	req := httptest.NewRequest(http.MethodPut, "/api/v1/tasks/123", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	h.UpdateTask(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("UpdateTask invalid status code = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}
