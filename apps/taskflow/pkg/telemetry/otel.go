package telemetry

import (
	"context"
	"fmt"
	"log/slog"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"go.opentelemetry.io/otel/trace"
	"go.opentelemetry.io/otel/trace/noop"
)

// InitTracer initializes OpenTelemetry tracing with OTLP exporter
func InitTracer(ctx context.Context, serviceName, otelEndpoint string, logger *slog.Logger) (func(context.Context) error, error) {
	// Create resource with service name
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// If no OTLP endpoint is provided, use a no-op tracer provider
	if otelEndpoint == "" {
		logger.Info("OTLP endpoint not configured, using no-op tracer")
		otel.SetTracerProvider(noop.NewTracerProvider())
		otel.SetTextMapPropagator(propagation.TraceContext{})
		return func(ctx context.Context) error { return nil }, nil
	}

	// Create OTLP trace exporter using the modern API
	// The exporter manages its own gRPC connection internally
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otelEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		logger.Warn("failed to create OTLP exporter, using no-op tracer", "error", err)
		otel.SetTracerProvider(noop.NewTracerProvider())
		otel.SetTextMapPropagator(propagation.TraceContext{})
		return func(ctx context.Context) error { return nil }, nil
	}

	// Create tracer provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	// Set global tracer provider
	otel.SetTracerProvider(tp)

	// Set global propagator to trace context (W3C Trace Context)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	logger.Info("OpenTelemetry tracer initialized", "service", serviceName, "endpoint", otelEndpoint)

	// Return shutdown function
	shutdown := func(ctx context.Context) error {
		logger.Info("Shutting down tracer provider")
		if err := tp.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown tracer provider: %w", err)
		}
		return nil
	}

	return shutdown, nil
}

// GetTracer returns a tracer for the given name
func GetTracer(name string) trace.Tracer {
	return otel.Tracer(name)
}
