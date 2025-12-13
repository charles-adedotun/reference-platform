# Observability Guide

Comprehensive guide to monitoring, logging, and tracing in the reference platform.

## Table of Contents

- [Overview](#overview)
- [Metrics with Prometheus](#metrics-with-prometheus)
- [Dashboards with Grafana](#dashboards-with-grafana)
- [Logs with Loki](#logs-with-loki)
- [Traces with Jaeger](#traces-with-jaeger)
- [Alerting](#alerting)
- [Log and Trace Correlation](#log-and-trace-correlation)
- [SLO Monitoring](#slo-monitoring)
- [Troubleshooting Workflows](#troubleshooting-workflows)

---

## Overview

The reference platform implements the three pillars of observability:

1. **Metrics**: Time-series data (Prometheus)
2. **Logs**: Structured event logs (Loki)
3. **Traces**: Distributed request tracing (Jaeger/Tempo)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Applications                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │   API    │  │  Worker  │  │  Database│                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │             │              │                         │
│       │ Metrics     │ Logs         │ Traces                 │
│       ├─────────────┼──────────────┤                        │
└───────┼─────────────┼──────────────┼─────────────────────────┘
        │             │              │
        ▼             ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│               Observability Stack                            │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │Prometheus│  │   Loki   │  │  Jaeger  │                 │
│  │  Metrics │  │   Logs   │  │ Traces   │                 │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
│       │             │              │                        │
│       └─────────────┴──────────────┘                       │
│                     │                                       │
│              ┌──────┴───────┐                              │
│              │   Grafana    │                              │
│              │  Dashboards  │                              │
│              └──────────────┘                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Metrics with Prometheus

### Installation

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Verify installation
kubectl get pods -n observability
kubectl get svc -n observability
```

### Instrumenting Applications

#### Golang Example

```go
package main

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "net/http"
)

var (
    // Counter: requests by endpoint and status
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"endpoint", "method", "status"},
    )

    // Histogram: request duration
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"endpoint", "method"},
    )

    // Gauge: active connections
    activeConnections = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "active_connections",
            Help: "Number of active database connections",
        },
    )
)

func instrumentHandler(endpoint string, handler http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(endpoint, r.Method))
        defer timer.ObserveDuration()

        handler(w, r)

        httpRequestsTotal.WithLabelValues(endpoint, r.Method, "200").Inc()
    }
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.HandleFunc("/api/users", instrumentHandler("/api/users", usersHandler))
    http.ListenAndServe(":8080", nil)
}
```

#### Python Example

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server
from functools import wraps
import time

# Metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['endpoint', 'method', 'status']
)

http_request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['endpoint', 'method']
)

active_connections = Gauge(
    'active_connections',
    'Active database connections'
)

def instrument_request(endpoint):
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            start = time.time()
            try:
                result = f(*args, **kwargs)
                http_requests_total.labels(
                    endpoint=endpoint,
                    method='GET',
                    status='200'
                ).inc()
                return result
            finally:
                duration = time.time() - start
                http_request_duration.labels(
                    endpoint=endpoint,
                    method='GET'
                ).observe(duration)
        return wrapped
    return decorator

# Start metrics server
start_http_server(8000)
```

### ServiceMonitor Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-metrics
  namespace: observability
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

### Common Metrics to Collect

```prometheus
# RED Method (Rate, Errors, Duration)
# Rate: Requests per second
rate(http_requests_total[5m])

# Errors: Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Duration: Request latency
http_request_duration_seconds

# USE Method (Utilization, Saturation, Errors)
# Utilization: CPU/Memory usage
container_cpu_usage_seconds_total
container_memory_usage_bytes

# Saturation: Queue depth
queue_depth

# Errors: Error count
errors_total

# Golden Signals
# Latency
histogram_quantile(0.95, http_request_duration_seconds)

# Traffic
rate(http_requests_total[5m])

# Errors
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# Saturation
process_resident_memory_bytes / node_memory_MemTotal_bytes
```

### Accessing Prometheus

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090
```

---

## Dashboards with Grafana

### Accessing Grafana

```bash
# Get Grafana admin password
kubectl get secret -n observability prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Port-forward to Grafana
kubectl port-forward -n observability svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Login: admin / <password-from-above>
```

### Creating Dashboards

#### Application Performance Dashboard

```json
{
  "dashboard": {
    "title": "Application Performance",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (endpoint)"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Latency (P95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Active Pods",
        "targets": [
          {
            "expr": "count(kube_pod_info{namespace=\"production\"})"
          }
        ],
        "type": "stat"
      }
    ]
  }
}
```

#### Database Dashboard

```json
{
  "dashboard": {
    "title": "Database Metrics",
    "panels": [
      {
        "title": "Active Connections",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends"
          }
        ]
      },
      {
        "title": "Transaction Rate",
        "targets": [
          {
            "expr": "rate(pg_stat_database_xact_commit[5m]) + rate(pg_stat_database_xact_rollback[5m])"
          }
        ]
      },
      {
        "title": "Cache Hit Ratio",
        "targets": [
          {
            "expr": "pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)"
          }
        ]
      }
    ]
  }
}
```

### Pre-built Dashboards

```bash
# Import popular dashboards
# Kubernetes Cluster Monitoring: ID 7249
# Node Exporter Full: ID 1860
# PostgreSQL Database: ID 9628
# Redis Dashboard: ID 11835

# Import via Grafana UI: + → Import → Enter dashboard ID
```

---

## Logs with Loki

### Installation

```bash
# Add Loki Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace observability \
  --set promtail.enabled=true \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi

# Verify installation
kubectl get pods -n observability -l app=loki
kubectl get pods -n observability -l app=promtail
```

### Structured Logging

#### Golang Example

```go
package main

import (
    "go.uber.org/zap"
)

func main() {
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    logger.Info("Processing request",
        zap.String("request_id", "abc-123"),
        zap.String("user_id", "user-456"),
        zap.String("endpoint", "/api/users"),
        zap.Int("status_code", 200),
        zap.Duration("duration", time.Second*2),
    )

    logger.Error("Database query failed",
        zap.String("request_id", "abc-123"),
        zap.Error(err),
        zap.String("query", "SELECT * FROM users"),
    )
}
```

#### Python Example

```python
import structlog
import logging

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
)

logger = structlog.get_logger()

logger.info(
    "processing_request",
    request_id="abc-123",
    user_id="user-456",
    endpoint="/api/users",
    status_code=200
)

logger.error(
    "database_query_failed",
    request_id="abc-123",
    error=str(e),
    query="SELECT * FROM users"
)
```

### Querying Logs in Grafana

```logql
# All logs from production namespace
{namespace="production"}

# Logs from specific app
{namespace="production", app="myapp"}

# Logs with error level
{namespace="production"} |= "level=error"

# Parse JSON and filter
{namespace="production"} | json | status_code >= 500

# Rate of errors
rate({namespace="production"} |= "error" [5m])

# Top endpoints by request count
topk(10,
  sum by (endpoint) (
    rate({namespace="production"} | json | __error__="" [5m])
  )
)
```

### Log Aggregation

```logql
# Count logs by level
sum by (level) (
  count_over_time({namespace="production"} | json [5m])
)

# P95 request duration from logs
quantile_over_time(0.95,
  {namespace="production"}
  | json
  | unwrap duration [5m]
)

# Error rate by endpoint
sum by (endpoint) (
  rate({namespace="production"} | json | status_code >= 500 [5m])
) / sum by (endpoint) (
  rate({namespace="production"} | json [5m])
)
```

---

## Traces with Jaeger

### Installation

```bash
# Install Jaeger Operator
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.42.0/jaeger-operator.yaml -n observability

# Create Jaeger instance
cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: production
  storage:
    type: elasticsearch
    options:
      es:
        server-urls: http://elasticsearch:9200
EOF

# Verify installation
kubectl get pods -n observability -l app=jaeger
```

### Instrumenting with OpenTelemetry

#### Golang Example

```go
package main

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/jaeger"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

func initTracer() func() {
    exporter, err := jaeger.New(
        jaeger.WithCollectorEndpoint(
            jaeger.WithEndpoint("http://jaeger-collector:14268/api/traces"),
        ),
    )
    if err != nil {
        panic(err)
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("myapp"),
        )),
    )

    otel.SetTracerProvider(tp)

    return func() {
        tp.Shutdown(context.Background())
    }
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    tracer := otel.Tracer("myapp")

    ctx, span := tracer.Start(ctx, "handleRequest")
    defer span.End()

    // Add attributes
    span.SetAttributes(
        attribute.String("user.id", "123"),
        attribute.String("http.method", r.Method),
    )

    // Create child span
    ctx, dbSpan := tracer.Start(ctx, "database.query")
    // ... perform database query
    dbSpan.End()

    // Record error if occurs
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
    }
}
```

#### Python Example

```python
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Initialize tracer
trace.set_tracer_provider(
    TracerProvider(
        resource=Resource.create({SERVICE_NAME: "myapp"})
    )
)

jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent",
    agent_port=6831,
)

trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

tracer = trace.get_tracer(__name__)

# Use tracer
def handle_request():
    with tracer.start_as_current_span("handle_request") as span:
        span.set_attribute("user.id", "123")
        span.set_attribute("http.method", "GET")

        with tracer.start_as_current_span("database.query"):
            # Perform database query
            pass

        if error:
            span.record_exception(error)
            span.set_status(Status(StatusCode.ERROR))
```

### Accessing Jaeger UI

```bash
# Port-forward to Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Open http://localhost:16686
```

---

## Alerting

### Alert Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: observability
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    # High error rate
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5.."}[5m])) by (namespace, app)
        /
        sum(rate(http_requests_total[5m])) by (namespace, app)
        > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "{{ $labels.app }} in {{ $labels.namespace }} has {{ $value | humanizePercentage }} error rate"
        runbook: "https://runbooks.example.com/high-error-rate"

    # High latency
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket[5m])) by (le, namespace, app)
        ) > 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "{{ $labels.app }} P95 latency is {{ $value }}s"

    # Pod down
    - alert: PodDown
      expr: |
        kube_deployment_status_replicas_available{namespace="production"}
        /
        kube_deployment_spec_replicas{namespace="production"}
        < 0.5
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Less than 50% pods available"
        description: "{{ $labels.deployment }} has only {{ $value | humanizePercentage }} pods available"

    # Database connection pool exhausted
    - alert: DatabaseConnectionPoolExhausted
      expr: |
        pg_stat_database_numbackends / pg_settings_max_connections > 0.9
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Database connection pool near exhaustion"
        description: "PostgreSQL using {{ $value | humanizePercentage }} of max connections"
        runbook: "https://runbooks.example.com/database-connection-exhausted"

    # Redis memory high
    - alert: RedisMemoryHigh
      expr: |
        redis_memory_used_bytes / redis_memory_max_bytes > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Redis memory usage high"
        description: "Redis using {{ $value | humanizePercentage }} of max memory"
```

### AlertManager Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: observability
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
      - match:
          severity: critical
        receiver: 'pagerduty'
        continue: true
      - match:
          severity: warning
        receiver: 'slack'

    receivers:
    - name: 'default'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

    - name: 'pagerduty'
      pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'

    - name: 'slack'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#alerts-warning'
```

---

## Log and Trace Correlation

### Adding Trace ID to Logs

```go
// Extract trace ID from context
func logWithTrace(ctx context.Context, msg string) {
    span := trace.SpanFromContext(ctx)
    traceID := span.SpanContext().TraceID().String()

    logger.Info(msg,
        zap.String("trace_id", traceID),
        zap.String("span_id", span.SpanContext().SpanID().String()),
    )
}
```

### Querying Logs by Trace ID

```logql
# Find all logs for a specific trace
{namespace="production"} | json | trace_id="abc123"

# Jump from trace to logs in Grafana
# Click on span → "Logs for this span"
```

### Trace Context Propagation

```go
// Propagate trace context in HTTP headers
import (
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// Client
client := &http.Client{
    Transport: otelhttp.NewTransport(http.DefaultTransport),
}

// Server
http.Handle("/api", otelhttp.NewHandler(apiHandler, "/api"))
```

---

## SLO Monitoring

### Defining SLOs

```yaml
# SLO: 99.9% availability
# Error budget: 0.1% = 43.2 minutes/month

apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-rules
spec:
  groups:
  - name: slo
    interval: 30s
    rules:
    # Availability SLO
    - record: slo:availability:ratio
      expr: |
        sum(rate(http_requests_total{status!~"5.."}[30d]))
        /
        sum(rate(http_requests_total[30d]))

    # Latency SLO (95% under 200ms)
    - record: slo:latency:ratio
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket[30d])) by (le)
        ) < 0.2

    # Error budget remaining
    - record: slo:error_budget:ratio
      expr: |
        1 - (
          (1 - slo:availability:ratio) / (1 - 0.999)
        )

    # Alert on error budget burn
    - alert: ErrorBudgetBurn
      expr: slo:error_budget:ratio < 0.1
      labels:
        severity: critical
      annotations:
        summary: "Error budget nearly exhausted"
        description: "Only {{ $value | humanizePercentage }} of error budget remaining"
```

### SLO Dashboard

```json
{
  "dashboard": {
    "title": "SLO Dashboard",
    "panels": [
      {
        "title": "Availability SLO (99.9%)",
        "targets": [{
          "expr": "slo:availability:ratio"
        }],
        "thresholds": [
          {"value": 0.999, "color": "red"},
          {"value": 0.9995, "color": "yellow"},
          {"value": 1, "color": "green"}
        ]
      },
      {
        "title": "Error Budget Remaining",
        "targets": [{
          "expr": "slo:error_budget:ratio"
        }]
      }
    ]
  }
}
```

---

## Troubleshooting Workflows

### High Error Rate Investigation

```
1. Check Grafana dashboard
   - Identify which endpoint has errors
   - Check error rate trend

2. Query Loki for error logs
   {namespace="production"} |= "error" | json | endpoint="/api/users"

3. Find trace ID from error log
   - Copy trace_id from log entry

4. Open trace in Jaeger
   - Search by trace ID
   - Identify slow/failing span

5. Check metrics for that component
   - Database slow queries?
   - External API timeout?

6. Correlate with recent changes
   - Check deployment history
   - Review recent commits

7. Follow runbook
   - See ../runbooks/ for remediation
```

### Performance Degradation Investigation

```
1. Check latency dashboard
   - P50, P95, P99 latency
   - Identify affected endpoints

2. View traces for slow requests
   - Filter by duration > threshold
   - Identify bottleneck spans

3. Check resource utilization
   - CPU, memory, network
   - Database connections

4. Query logs for patterns
   - Slow query logs
   - GC pauses
   - Connection timeouts

5. Review recent changes
   - Code deployments
   - Config changes
   - Traffic spikes

6. Apply remediation
   - Scale horizontally
   - Optimize slow code path
   - Increase resources
```

---

## References

- [Architecture Documentation](./architecture.md)
- [Deployment Guide](./deployment.md)
- [Runbooks](../runbooks/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry](https://opentelemetry.io/)
