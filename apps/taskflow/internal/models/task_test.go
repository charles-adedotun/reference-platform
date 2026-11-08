package models

import "testing"

func TestCreateTaskRequest_Validate(t *testing.T) {
	valid := CreateTaskRequest{Title: "Deploy EKS", Priority: 5}
	if err := valid.Validate(); err != nil {
		t.Errorf("expected valid request, got %v", err)
	}

	missingTitle := CreateTaskRequest{Title: "", Priority: 5}
	if err := missingTitle.Validate(); err == nil {
		t.Error("expected error for empty title, got nil")
	}

	badPriority := CreateTaskRequest{Title: "Deploy", Priority: 11}
	if err := badPriority.Validate(); err == nil {
		t.Error("expected error for priority > 10, got nil")
	}
}

func TestUpdateTaskRequest_Validate(t *testing.T) {
	validStatus := StatusCompleted
	validPrio := 3
	req := UpdateTaskRequest{Status: &validStatus, Priority: &validPrio}
	if err := req.Validate(); err != nil {
		t.Errorf("expected valid update request, got %v", err)
	}

	badStatus := "unknown_status"
	badReq := UpdateTaskRequest{Status: &badStatus}
	if err := badReq.Validate(); err == nil {
		t.Error("expected error for invalid status, got nil")
	}
}
