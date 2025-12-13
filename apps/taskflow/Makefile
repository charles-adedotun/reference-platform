.PHONY: help build run test clean docker-build docker-push migrate

help:
	@echo "TaskFlow Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build         - Build all binaries"
	@echo "  build-api     - Build API server"
	@echo "  build-worker  - Build worker"
	@echo "  build-cron    - Build cron job"
	@echo "  run-api       - Run API server"
	@echo "  run-worker    - Run worker"
	@echo "  run-cron      - Run cron job"
	@echo "  test          - Run tests"
	@echo "  clean         - Clean build artifacts"
	@echo "  docker-build  - Build Docker images"
	@echo "  migrate-up    - Run database migrations"
	@echo "  migrate-down  - Rollback database migrations"

build: build-api build-worker build-cron

build-api:
	@echo "Building API server..."
	@go build -o bin/api ./cmd/api

build-worker:
	@echo "Building worker..."
	@go build -o bin/worker ./cmd/worker

build-cron:
	@echo "Building cron job..."
	@go build -o bin/cron ./cmd/cron

run-api: build-api
	@echo "Running API server..."
	@./bin/api

run-worker: build-worker
	@echo "Running worker..."
	@./bin/worker

run-cron: build-cron
	@echo "Running cron job..."
	@./bin/cron

test:
	@echo "Running tests..."
	@go test -v -race -coverprofile=coverage.out ./...

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/
	@rm -f coverage.out

docker-build:
	@echo "Building Docker images..."
	@docker build -f build/Dockerfile.api -t taskflow-api:latest .
	@docker build -f build/Dockerfile.worker -t taskflow-worker:latest .
	@docker build -f build/Dockerfile.cron -t taskflow-cron:latest .

docker-push: docker-build
	@echo "Pushing Docker images..."
	@docker push taskflow-api:latest
	@docker push taskflow-worker:latest
	@docker push taskflow-cron:latest

migrate-up:
	@echo "Running database migrations..."
	@psql $(DATABASE_URL) -f internal/database/migrations/001_create_tasks_table.up.sql

migrate-down:
	@echo "Rolling back database migrations..."
	@psql $(DATABASE_URL) -f internal/database/migrations/001_create_tasks_table.down.sql

fmt:
	@echo "Formatting code..."
	@go fmt ./...

vet:
	@echo "Vetting code..."
	@go vet ./...

lint:
	@echo "Linting code..."
	@golangci-lint run

deps:
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy

.DEFAULT_GOAL := help
