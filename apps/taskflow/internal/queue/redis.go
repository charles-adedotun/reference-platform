package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	// TaskQueueKey is the Redis key for the task queue
	TaskQueueKey = "taskflow:queue:tasks"
)

// Queue wraps Redis client for queue operations
type Queue struct {
	client *redis.Client
	logger *slog.Logger
}

// TaskMessage represents a message in the task queue
type TaskMessage struct {
	TaskID    string    `json:"task_id"`
	Action    string    `json:"action"`
	Timestamp time.Time `json:"timestamp"`
}

// NewQueue creates a new Redis queue client
func NewQueue(addr, password string, db int, logger *slog.Logger) (*Queue, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     password,
		DB:           db,
		MaxRetries:   3,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		MinIdleConns: 5,
	})

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	logger.Info("Redis queue connection established", "addr", addr, "db", db)

	return &Queue{
		client: client,
		logger: logger,
	}, nil
}

// Close closes the Redis connection
func (q *Queue) Close() error {
	q.logger.Info("Closing Redis connection")
	return q.client.Close()
}

// HealthCheck checks if Redis is healthy
func (q *Queue) HealthCheck(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	if err := q.client.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("Redis health check failed: %w", err)
	}

	return nil
}

// Enqueue adds a task to the queue
func (q *Queue) Enqueue(ctx context.Context, taskID, action string) error {
	msg := TaskMessage{
		TaskID:    taskID,
		Action:    action,
		Timestamp: time.Now(),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal task message: %w", err)
	}

	if err := q.client.RPush(ctx, TaskQueueKey, data).Err(); err != nil {
		return fmt.Errorf("failed to enqueue task: %w", err)
	}

	q.logger.Info("Task enqueued",
		"task_id", taskID,
		"action", action,
	)

	return nil
}

// Dequeue removes and returns a task from the queue
// It blocks until a task is available or the context is cancelled
func (q *Queue) Dequeue(ctx context.Context, timeout time.Duration) (*TaskMessage, error) {
	result, err := q.client.BLPop(ctx, timeout, TaskQueueKey).Result()
	if err != nil {
		if err == redis.Nil {
			// No task available within timeout
			return nil, nil
		}
		return nil, fmt.Errorf("failed to dequeue task: %w", err)
	}

	// BLPop returns [key, value]
	if len(result) < 2 {
		return nil, fmt.Errorf("unexpected BLPop result")
	}

	var msg TaskMessage
	if err := json.Unmarshal([]byte(result[1]), &msg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal task message: %w", err)
	}

	return &msg, nil
}

// QueueLength returns the number of tasks in the queue
func (q *Queue) QueueLength(ctx context.Context) (int64, error) {
	length, err := q.client.LLen(ctx, TaskQueueKey).Result()
	if err != nil {
		return 0, fmt.Errorf("failed to get queue length: %w", err)
	}
	return length, nil
}
