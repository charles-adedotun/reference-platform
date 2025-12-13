# TaskFlow Quick Start Guide

This guide will help you get TaskFlow up and running quickly.

## Prerequisites

- Docker and Docker Compose installed
- OR Go 1.21+, PostgreSQL 14+, and Redis 6+

## Option 1: Docker Compose (Recommended)

The easiest way to run TaskFlow is with Docker Compose:

```bash
# Build and start all services
docker-compose up --build

# The API will be available at http://localhost:8080
```

This will start:
- PostgreSQL database
- Redis queue
- API server (port 8080)
- Worker process
- Cron job

## Option 2: Local Development

### 1. Set up dependencies

Start PostgreSQL and Redis:

```bash
# Using Docker
docker run -d --name postgres -p 5432:5432 \
  -e POSTGRES_DB=taskflow \
  -e POSTGRES_USER=taskflow \
  -e POSTGRES_PASSWORD=taskflow123 \
  postgres:16-alpine

docker run -d --name redis -p 6379:6379 redis:7-alpine
```

### 2. Configure environment

```bash
cp .env.example .env

# Edit .env with your configuration
export DATABASE_URL="postgres://taskflow:taskflow123@localhost:5432/taskflow?sslmode=disable"
export REDIS_ADDR="localhost:6379"
export PORT="8080"
```

### 3. Run database migrations

```bash
make migrate-up
```

### 4. Build and run services

In separate terminal windows:

```bash
# Terminal 1: API Server
make run-api

# Terminal 2: Worker
make run-worker

# Terminal 3: Cron Job
make run-cron
```

## Testing the API

### Create a task

```bash
curl -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My first task",
    "description": "This is a test task",
    "priority": 5
  }'
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "My first task",
  "description": "This is a test task",
  "status": "pending",
  "priority": 5,
  "created_at": "2025-01-01T12:00:00Z",
  "updated_at": "2025-01-01T12:00:00Z"
}
```

### List all tasks

```bash
curl http://localhost:8080/api/v1/tasks
```

### Get a specific task

```bash
curl http://localhost:8080/api/v1/tasks/{task-id}
```

### Update a task

```bash
curl -X PUT http://localhost:8080/api/v1/tasks/{task-id} \
  -H "Content-Type: application/json" \
  -d '{
    "status": "completed"
  }'
```

### Delete a task

```bash
curl -X DELETE http://localhost:8080/api/v1/tasks/{task-id}
```

### Run synthetic transaction (for monitoring)

```bash
curl -X POST http://localhost:8080/api/v1/transaction
```

Response:
```json
{
  "transaction_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "duration": "125ms",
  "steps": [
    {
      "name": "create_task",
      "duration": "45ms",
      "status": "success"
    },
    {
      "name": "enqueue_task",
      "duration": "12ms",
      "status": "success"
    },
    {
      "name": "retrieve_task",
      "duration": "23ms",
      "status": "success"
    },
    {
      "name": "update_task",
      "duration": "31ms",
      "status": "success"
    },
    {
      "name": "check_queue",
      "duration": "14ms",
      "status": "success"
    }
  ],
  "metadata": {
    "task_id": "550e8400-e29b-41d4-a716-446655440000",
    "task_title": "Synthetic monitoring task 2025-01-01T12:00:00Z",
    "task_status": "processing",
    "queue_length": 1,
    "timestamp": "2025-01-01T12:00:00Z"
  }
}
```

## Health Checks

```bash
# Liveness probe
curl http://localhost:8080/health

# Readiness probe (checks database and Redis)
curl http://localhost:8080/ready
```

## Observability

### Structured Logs

All services output JSON structured logs to stdout:

```json
{
  "time": "2025-01-01T12:00:00.000Z",
  "level": "INFO",
  "msg": "Task created",
  "service": "taskflow-api",
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "My first task",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7"
}
```

### OpenTelemetry Tracing

To enable tracing, set the OTLP endpoint:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
```

Traces will include:
- HTTP requests with route, method, and status code
- Database queries
- Queue operations
- Background job execution

## How It Works

1. **API Server**: Receives HTTP requests, stores tasks in PostgreSQL, and enqueues them in Redis
2. **Worker**: Continuously polls Redis for tasks and processes them (simulates work, then marks as completed)
3. **Cron Job**: Runs hourly to clean up tasks completed more than 7 days ago

## Development

### Build binaries

```bash
make build
```

### Run tests

```bash
make test
```

### Build Docker images

```bash
make docker-build
```

### Format code

```bash
make fmt
```

## Troubleshooting

### Database connection errors

Ensure PostgreSQL is running and the connection string is correct:

```bash
psql $DATABASE_URL -c "SELECT 1"
```

### Redis connection errors

Ensure Redis is running:

```bash
redis-cli ping
```

### Port already in use

Change the port in `.env`:

```bash
export PORT=8081
```

## Next Steps

- Deploy to Kubernetes using the Helm chart in `deploy/helm/taskflow/`
- Configure OpenTelemetry collector for distributed tracing
- Set up Prometheus metrics scraping
- Configure log aggregation (e.g., Loki, Elasticsearch)

## Clean Up

### Docker Compose

```bash
docker-compose down -v
```

### Local Development

```bash
# Stop services with Ctrl+C

# Drop database
make migrate-down

# Remove Docker containers
docker stop postgres redis
docker rm postgres redis
```
