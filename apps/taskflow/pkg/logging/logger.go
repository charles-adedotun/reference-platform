package logging

import (
	"context"
	"log/slog"
	"os"

	"go.opentelemetry.io/otel/trace"
)

// NewLogger creates a new JSON structured logger with OpenTelemetry integration
func NewLogger(serviceName string) *slog.Logger {
	// Create a handler that adds trace context to log entries
	handler := NewOtelHandler(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	return slog.New(handler).With(
		slog.String("service", serviceName),
	)
}

// OtelHandler wraps a slog.Handler to add OpenTelemetry trace context
type OtelHandler struct {
	handler slog.Handler
}

// NewOtelHandler creates a new handler that adds trace_id and span_id to logs
func NewOtelHandler(handler slog.Handler) *OtelHandler {
	return &OtelHandler{handler: handler}
}

func (h *OtelHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return h.handler.Enabled(ctx, level)
}

func (h *OtelHandler) Handle(ctx context.Context, record slog.Record) error {
	// Extract trace context from the context
	spanCtx := trace.SpanFromContext(ctx).SpanContext()

	if spanCtx.IsValid() {
		record.AddAttrs(
			slog.String("trace_id", spanCtx.TraceID().String()),
			slog.String("span_id", spanCtx.SpanID().String()),
		)
	}

	return h.handler.Handle(ctx, record)
}

func (h *OtelHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &OtelHandler{handler: h.handler.WithAttrs(attrs)}
}

func (h *OtelHandler) WithGroup(name string) slog.Handler {
	return &OtelHandler{handler: h.handler.WithGroup(name)}
}

// FromContext returns a logger with trace context from the given context
func FromContext(ctx context.Context, logger *slog.Logger) *slog.Logger {
	spanCtx := trace.SpanFromContext(ctx).SpanContext()
	if spanCtx.IsValid() {
		return logger.With(
			slog.String("trace_id", spanCtx.TraceID().String()),
			slog.String("span_id", spanCtx.SpanID().String()),
		)
	}
	return logger
}
