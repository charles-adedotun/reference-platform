package config

import (
	"testing"
	"time"
)

func TestLoadConfig_Defaults(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("DB_HOST", "db.internal")
	t.Setenv("DB_PORT", "5432")
	t.Setenv("DB_NAME", "taskflow_test")
	t.Setenv("DB_USER", "tester")
	t.Setenv("DB_PASSWORD", "secret123")
	t.Setenv("DB_SSL_MODE", "disable")
	t.Setenv("PORT", "9090")
	t.Setenv("REDIS_ADDR", "redis.internal:6379")
	t.Setenv("REDIS_DB", "2")
	t.Setenv("OTEL_INSECURE", "true")
	t.Setenv("SHUTDOWN_TIMEOUT", "15s")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() unexpected error: %v", err)
	}

	wantURL := "postgresql://tester:secret123@db.internal:5432/taskflow_test?sslmode=disable"
	if cfg.DatabaseURL != wantURL {
		t.Errorf("DatabaseURL = %q, want %q", cfg.DatabaseURL, wantURL)
	}
	if cfg.ServerPort != "9090" {
		t.Errorf("ServerPort = %q, want 9090", cfg.ServerPort)
	}
	if cfg.RedisDB != 2 {
		t.Errorf("RedisDB = %d, want 2", cfg.RedisDB)
	}
	if !cfg.OTELInsecure {
		t.Errorf("OTELInsecure = false, want true")
	}
	if cfg.ShutdownTimeout != 15*time.Second {
		t.Errorf("ShutdownTimeout = %v, want 15s", cfg.ShutdownTimeout)
	}
}

func TestLoadConfig_ExplicitDatabaseURLAndInvalidEnvFallbacks(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgresql://explicit:5432/db")
	t.Setenv("REDIS_DB", "not-an-int")
	t.Setenv("OTEL_INSECURE", "not-a-bool")
	t.Setenv("SHUTDOWN_TIMEOUT", "invalid-duration")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() unexpected error: %v", err)
	}
	if cfg.DatabaseURL != "postgresql://explicit:5432/db" {
		t.Errorf("DatabaseURL = %q, want explicit URL", cfg.DatabaseURL)
	}
	if cfg.RedisDB != 0 {
		t.Errorf("RedisDB fallback = %d, want 0", cfg.RedisDB)
	}
	if cfg.OTELInsecure {
		t.Errorf("OTELInsecure fallback = true, want false")
	}
	if cfg.ShutdownTimeout != 30*time.Second {
		t.Errorf("ShutdownTimeout fallback = %v, want 30s", cfg.ShutdownTimeout)
	}
}
