package models

import (
	"time"
)

// Task represents a task in the system
type Task struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Status      string    `json:"status"`
	Priority    int       `json:"priority"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// TaskStatus constants
const (
	StatusPending    = "pending"
	StatusProcessing = "processing"
	StatusCompleted  = "completed"
	StatusFailed     = "failed"
)

// CreateTaskRequest represents a request to create a new task
type CreateTaskRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Priority    int    `json:"priority"`
}

// UpdateTaskRequest represents a request to update a task
type UpdateTaskRequest struct {
	Title       *string `json:"title,omitempty"`
	Description *string `json:"description,omitempty"`
	Status      *string `json:"status,omitempty"`
	Priority    *int    `json:"priority,omitempty"`
}

// Validate validates the CreateTaskRequest
func (r *CreateTaskRequest) Validate() error {
	if r.Title == "" {
		return ErrInvalidInput("title is required")
	}
	if r.Priority < 0 || r.Priority > 10 {
		return ErrInvalidInput("priority must be between 0 and 10")
	}
	return nil
}

// Validate validates the UpdateTaskRequest
func (r *UpdateTaskRequest) Validate() error {
	if r.Status != nil {
		status := *r.Status
		if status != StatusPending && status != StatusProcessing &&
		   status != StatusCompleted && status != StatusFailed {
			return ErrInvalidInput("invalid status value")
		}
	}
	if r.Priority != nil {
		if *r.Priority < 0 || *r.Priority > 10 {
			return ErrInvalidInput("priority must be between 0 and 10")
		}
	}
	return nil
}

// ValidationError represents a validation error
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}

// ErrInvalidInput creates a new validation error
func ErrInvalidInput(message string) error {
	return &ValidationError{Message: message}
}
