package database

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/reference-platform/taskflow/internal/models"
)

// DB wraps the pgxpool.Pool with additional functionality
type DB struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

// NewDB creates a new database connection pool
func NewDB(ctx context.Context, databaseURL string, logger *slog.Logger) (*DB, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database URL: %w", err)
	}

	// Set connection pool settings
	config.MaxConns = 25
	config.MinConns = 5
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute
	config.HealthCheckPeriod = time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Test the connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Database connection established",
		"max_conns", config.MaxConns,
		"min_conns", config.MinConns,
	)

	return &DB{
		pool:   pool,
		logger: logger,
	}, nil
}

// Close closes the database connection pool
func (db *DB) Close() {
	db.logger.Info("Closing database connection pool")
	db.pool.Close()
}

// HealthCheck checks if the database is healthy
func (db *DB) HealthCheck(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	if err := db.pool.Ping(ctx); err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}

	return nil
}

// CreateTask creates a new task in the database
func (db *DB) CreateTask(ctx context.Context, req *models.CreateTaskRequest) (*models.Task, error) {
	query := `
		INSERT INTO tasks (title, description, status, priority)
		VALUES ($1, $2, $3, $4)
		RETURNING id, title, description, status, priority, created_at, updated_at, completed_at
	`

	task := &models.Task{}
	err := db.pool.QueryRow(ctx, query,
		req.Title,
		req.Description,
		models.StatusPending,
		req.Priority,
	).Scan(
		&task.ID,
		&task.Title,
		&task.Description,
		&task.Status,
		&task.Priority,
		&task.CreatedAt,
		&task.UpdatedAt,
		&task.CompletedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create task: %w", err)
	}

	return task, nil
}

// GetTask retrieves a task by ID
func (db *DB) GetTask(ctx context.Context, id string) (*models.Task, error) {
	query := `
		SELECT id, title, description, status, priority, created_at, updated_at, completed_at
		FROM tasks
		WHERE id = $1
	`

	task := &models.Task{}
	err := db.pool.QueryRow(ctx, query, id).Scan(
		&task.ID,
		&task.Title,
		&task.Description,
		&task.Status,
		&task.Priority,
		&task.CreatedAt,
		&task.UpdatedAt,
		&task.CompletedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get task: %w", err)
	}

	return task, nil
}

// ListTasks retrieves all tasks
func (db *DB) ListTasks(ctx context.Context) ([]*models.Task, error) {
	query := `
		SELECT id, title, description, status, priority, created_at, updated_at, completed_at
		FROM tasks
		ORDER BY created_at DESC
		LIMIT 100
	`

	rows, err := db.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to list tasks: %w", err)
	}
	defer rows.Close()

	var tasks []*models.Task
	for rows.Next() {
		task := &models.Task{}
		err := rows.Scan(
			&task.ID,
			&task.Title,
			&task.Description,
			&task.Status,
			&task.Priority,
			&task.CreatedAt,
			&task.UpdatedAt,
			&task.CompletedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan task: %w", err)
		}
		tasks = append(tasks, task)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tasks: %w", err)
	}

	return tasks, nil
}

// UpdateTask updates a task by ID
func (db *DB) UpdateTask(ctx context.Context, id string, req *models.UpdateTaskRequest) (*models.Task, error) {
	// Build dynamic update query
	query := `UPDATE tasks SET updated_at = NOW()`
	args := []interface{}{}
	argPos := 1

	if req.Title != nil {
		argPos++
		query += fmt.Sprintf(", title = $%d", argPos)
		args = append(args, *req.Title)
	}

	if req.Description != nil {
		argPos++
		query += fmt.Sprintf(", description = $%d", argPos)
		args = append(args, *req.Description)
	}

	if req.Status != nil {
		argPos++
		query += fmt.Sprintf(", status = $%d", argPos)
		args = append(args, *req.Status)

		// If status is completed, set completed_at
		if *req.Status == models.StatusCompleted {
			query += ", completed_at = NOW()"
		}
	}

	if req.Priority != nil {
		argPos++
		query += fmt.Sprintf(", priority = $%d", argPos)
		args = append(args, *req.Priority)
	}

	query += fmt.Sprintf(" WHERE id = $1 RETURNING id, title, description, status, priority, created_at, updated_at, completed_at")
	args = append([]interface{}{id}, args...)

	task := &models.Task{}
	err := db.pool.QueryRow(ctx, query, args...).Scan(
		&task.ID,
		&task.Title,
		&task.Description,
		&task.Status,
		&task.Priority,
		&task.CreatedAt,
		&task.UpdatedAt,
		&task.CompletedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to update task: %w", err)
	}

	return task, nil
}

// DeleteTask deletes a task by ID
func (db *DB) DeleteTask(ctx context.Context, id string) error {
	query := `DELETE FROM tasks WHERE id = $1`

	result, err := db.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete task: %w", err)
	}

	if result.RowsAffected() == 0 {
		return fmt.Errorf("task not found")
	}

	return nil
}

// DeleteOldCompletedTasks deletes completed tasks older than the specified duration
func (db *DB) DeleteOldCompletedTasks(ctx context.Context, olderThan time.Duration) (int64, error) {
	query := `
		DELETE FROM tasks
		WHERE status = $1
		AND completed_at < NOW() - $2::interval
	`

	result, err := db.pool.Exec(ctx, query, models.StatusCompleted, olderThan)
	if err != nil {
		return 0, fmt.Errorf("failed to delete old tasks: %w", err)
	}

	return result.RowsAffected(), nil
}
