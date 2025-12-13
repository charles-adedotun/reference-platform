# TaskFlow

A reference implementation of a task management application built with Go, demonstrating best practices for microservices architecture, observability, and cloud-native development.

## Features

- **RESTful API** for task management (CRUD operations)
- **Queue-based processing** with Redis
- **Scheduled cleanup** of old completed tasks
- **OpenTelemetry integration** for distributed tracing
- **Structured logging** with trace/span ID correlation
- **Health checks** (liveness and readiness probes)
- **Graceful shutdown** handling
- **Synthetic transaction monitoring** endpoint
- **Production-ready Docker images** (~15MB)

## Architecture

TaskFlow consists of three components:

1. **API Server** (`cmd/api`) - HTTP REST API for task management
2. **Worker** (`cmd/worker`) - Background worker that processes tasks from Redis queue
3. **Cron Job** (`cmd/cron`) - Periodic cleanup of old completed tasks

## Prerequisites

- Go 1.21 or later
- PostgreSQL 14+
- Redis 6+
- Docker (optional, for containerized deployment)

## Getting Started

### Local Development

1. **Clone the repository**

```bash
git clone <repository-url>
cd taskflow
```

2. **Install dependencies**

```bash
go mod download
```

3. **Set up environment variables**

```bash
cp .env.example .env
# Edit .env with your configuration
```

4. **Run database migrations**

```bash
make migrate-up
```

5. **Run the services**

```bash
# Terminal 1: API Server
make run-api

# Terminal 2: Worker
make run-worker

# Terminal 3: Cron Job
make run-cron
```

### Docker Deployment

1. **Build Docker images**

```bash
make docker-build
```

2. **Run with Docker Compose**

```bash
docker-compose up
```

## API Endpoints

### Health Checks

- `GET /health` - Liveness probe (always returns 200)
- `GET /ready` - Readiness probe (checks database and Redis connectivity)

### Task Management

- `POST /api/v1/tasks` - Create a new task
- `GET /api/v1/tasks` - List all tasks
- `GET /api/v1/tasks/{id}` - Get a specific task
- `PUT /api/v1/tasks/{id}` - Update a task
- `DELETE /api/v1/tasks/{id}` - Delete a task

### Monitoring

- `POST /api/v1/transaction` - Synthetic transaction for monitoring (creates, enqueues, retrieves, and updates a task)

## Example Usage

### Create a Task

```bash
curl -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Complete project documentation",
    "description": "Write comprehensive docs for the TaskFlow project",
    "priority": 5
  }'
```

### List Tasks

```bash
curl http://localhost:8080/api/v1/tasks
```

### Update Task Status

```bash
curl -X PUT http://localhost:8080/api/v1/tasks/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "status": "completed"
  }'
```

### Synthetic Transaction

```bash
curl -X POST http://localhost:8080/api/v1/transaction
```

## Configuration

Configuration is done via environment variables. See `.env.example` for all available options.

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `8080` |
| `SERVICE_NAME` | Service name for logging/tracing | `taskflow` |
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `REDIS_ADDR` | Redis server address | `localhost:6379` |
| `REDIS_PASSWORD` | Redis password | Empty |
| `REDIS_DB` | Redis database number | `0` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry collector endpoint | Empty (disabled) |
| `SHUTDOWN_TIMEOUT` | Graceful shutdown timeout | `30s` |

## Observability

### Structured Logging

All logs are output in JSON format with the following fields:
- `timestamp` - ISO 8601 timestamp
- `level` - Log level (INFO, WARN, ERROR)
- `msg` - Log message
- `service` - Service name
- `trace_id` - OpenTelemetry trace ID (when available)
- `span_id` - OpenTelemetry span ID (when available)

### Distributed Tracing

When `OTEL_EXPORTER_OTLP_ENDPOINT` is configured, the application exports traces to an OpenTelemetry collector. All HTTP requests and background jobs are traced.

Example trace hierarchy:
```
CreateTask
├── Database Insert
└── Queue Enqueue

ProcessTask (Worker)
├── Queue Dequeue
└── Database Update
```

## Database Schema

### Tasks Table

```sql
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    priority INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);
```

Indexes:
- `idx_tasks_status` - Status queries
- `idx_tasks_created_at` - Sorting by creation time
- `idx_tasks_priority` - Priority-based queries
- `idx_tasks_completed_at` - Cleanup queries

## Development

### Building

```bash
# Build all services
make build

# Build specific service
make build-api
make build-worker
make build-cron
```

### Testing

```bash
# Run tests
make test

# Run tests with coverage
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Code Quality

```bash
# Format code
make fmt

# Vet code
make vet

# Lint (requires golangci-lint)
make lint
```

## Docker Images

The application uses multi-stage Docker builds to create minimal, secure images:

- Base image: `scratch` (no OS dependencies)
- Size: ~15MB per service
- CGO disabled for static linking
- Includes only CA certificates and the binary

## Production Considerations

1. **Database Connection Pooling** - Configured with sensible defaults (max 25, min 5 connections)
2. **Graceful Shutdown** - All services handle SIGTERM/SIGINT properly
3. **Health Checks** - Kubernetes-compatible liveness and readiness probes
4. **Timeouts** - Request timeouts, shutdown timeouts, database query timeouts
5. **Error Handling** - Comprehensive error handling with proper logging
6. **Security** - No secrets in code, environment-based configuration
7. **Observability** - Structured logging and distributed tracing ready

## License

MIT License - See LICENSE file for details
