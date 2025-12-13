package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the application
type Config struct {
	// Server configuration
	ServerPort string

	// Database configuration
	DatabaseURL string

	// Redis configuration
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// OpenTelemetry configuration
	OTELEndpoint string
	OTELInsecure bool // Use insecure connection (no TLS) - only for local development

	// Service name
	ServiceName string

	// Graceful shutdown timeout
	ShutdownTimeout time.Duration

	// Database SSL mode (disable, require, verify-ca, verify-full)
	DBSSLMode string
}

// LoadConfig loads configuration from environment variables
func LoadConfig() (*Config, error) {
	// Support both DATABASE_URL and separate DB_* env vars
	// Separate vars are preferred for security (password not in URL)
	databaseURL := getEnv("DATABASE_URL", "")
	// SSL mode: disable (dev only), require (default), verify-ca, verify-full (production)
	dbSSLMode := getEnv("DB_SSL_MODE", "require")
	if databaseURL == "" {
		// Construct from separate env vars
		dbHost := getEnv("DB_HOST", "localhost")
		dbPort := getEnv("DB_PORT", "5432")
		dbName := getEnv("DB_NAME", "taskflow")
		dbUser := getEnv("DB_USER", "taskflow")
		dbPassword := getEnv("DB_PASSWORD", "")
		if dbPassword != "" {
			databaseURL = fmt.Sprintf("postgresql://%s:%s@%s:%s/%s?sslmode=%s",
				dbUser, dbPassword, dbHost, dbPort, dbName, dbSSLMode)
		} else {
			databaseURL = fmt.Sprintf("postgresql://%s@%s:%s/%s?sslmode=%s",
				dbUser, dbHost, dbPort, dbName, dbSSLMode)
		}
	}

	cfg := &Config{
		ServerPort:      getEnv("PORT", "8080"),
		DatabaseURL:     databaseURL,
		DBSSLMode:       dbSSLMode,
		RedisAddr:       getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword:   getEnv("REDIS_PASSWORD", ""),
		RedisDB:         getEnvAsInt("REDIS_DB", 0),
		OTELEndpoint:    getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		OTELInsecure:    getEnvAsBool("OTEL_INSECURE", false),
		ServiceName:     getEnv("SERVICE_NAME", "taskflow"),
		ShutdownTimeout: getEnvAsDuration("SHUTDOWN_TIMEOUT", "30s"),
	}

	// Validate required configuration
	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL or DB_HOST/DB_NAME/DB_USER are required")
	}

	return cfg, nil
}

// getEnv retrieves an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvAsInt retrieves an environment variable as an integer or returns a default value
func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// getEnvAsDuration retrieves an environment variable as a duration or returns a default value
func getEnvAsDuration(key string, defaultValue string) time.Duration {
	value := getEnv(key, defaultValue)
	duration, err := time.ParseDuration(value)
	if err != nil {
		duration, _ = time.ParseDuration(defaultValue)
	}
	return duration
}

// getEnvAsBool retrieves an environment variable as a boolean or returns a default value
func getEnvAsBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolVal, err := strconv.ParseBool(value); err == nil {
			return boolVal
		}
	}
	return defaultValue
}
