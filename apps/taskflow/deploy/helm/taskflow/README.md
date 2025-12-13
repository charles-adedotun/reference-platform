# TaskFlow Helm Chart

A Helm chart for deploying TaskFlow - a distributed task execution platform on Kubernetes.

## Overview

This chart deploys the following components:

- **API Service**: REST API for task management (with HPA and PDB)
- **Worker Service**: Task execution workers (with HPA)
- **Cron Jobs**: Scheduled cleanup and maintenance tasks
- **PostgreSQL**: Primary database (StatefulSet with persistence)
- **Redis**: Message broker and cache
- **Migration Job**: Database migration hook
- **Network Policies**: Pod-to-pod communication rules
- **Service Account**: RBAC configuration

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Installation

### Install with default values (production)

```bash
helm install taskflow ./taskflow
```

### Install for local development (Kind cluster)

```bash
helm install taskflow ./taskflow -f values-kind.yaml
```

### Install with custom values

```bash
helm install taskflow ./taskflow -f my-values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `api.replicaCount` | Number of API replicas | `3` |
| `api.autoscaling.enabled` | Enable HPA for API | `true` |
| `api.autoscaling.minReplicas` | Minimum API replicas | `3` |
| `api.autoscaling.maxReplicas` | Maximum API replicas | `10` |
| `worker.replicaCount` | Number of worker replicas | `5` |
| `worker.concurrency` | Worker concurrency level | `10` |
| `worker.autoscaling.enabled` | Enable HPA for workers | `true` |
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `postgresql.persistence.enabled` | Enable PostgreSQL persistence | `true` |
| `postgresql.persistence.size` | PostgreSQL PVC size | `10Gi` |
| `redis.enabled` | Deploy Redis | `true` |
| `redis.persistence.enabled` | Enable Redis persistence | `true` |
| `redis.persistence.size` | Redis PVC size | `5Gi` |
| `telemetry.enabled` | Enable OpenTelemetry | `true` |
| `networkPolicy.enabled` | Enable Network Policies | `true` |

### Security

All components are configured with security best practices:

- `runAsNonRoot: true`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- Capabilities dropped: `ALL`
- Non-root user ID: `1000` (workers/api), `999` (postgres/redis)

### Resource Limits

Production defaults:

```yaml
api:
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

worker:
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
```

Kind/Development values (values-kind.yaml):

```yaml
api:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## Usage Examples

### Upgrade the deployment

```bash
helm upgrade taskflow ./taskflow
```

### Upgrade with new values

```bash
helm upgrade taskflow ./taskflow -f my-values.yaml
```

### Rollback to previous version

```bash
helm rollback taskflow
```

### Uninstall

```bash
helm uninstall taskflow
```

### Port forwarding (for local access)

```bash
# Forward API service
kubectl port-forward svc/taskflow-api 8000:8000

# Access at http://localhost:8000
```

### Accessing logs

```bash
# API logs
kubectl logs -f -l app.kubernetes.io/component=api

# Worker logs
kubectl logs -f -l app.kubernetes.io/component=worker

# PostgreSQL logs
kubectl logs -f -l app.kubernetes.io/component=postgresql

# Redis logs
kubectl logs -f -l app.kubernetes.io/component=redis
```

### Scaling manually

```bash
# Scale API
kubectl scale deployment taskflow-api --replicas=5

# Scale Workers
kubectl scale deployment taskflow-worker --replicas=10
```

## Development

### Validate the chart

```bash
helm lint ./taskflow
```

### Dry run installation

```bash
helm install taskflow ./taskflow --dry-run --debug
```

### Template rendering

```bash
helm template taskflow ./taskflow
```

### Package the chart

```bash
helm package ./taskflow
```

## Troubleshooting

### Check pod status

```bash
kubectl get pods -l app.kubernetes.io/name=taskflow
```

### Check migration job

```bash
kubectl get jobs -l app.kubernetes.io/component=migration
kubectl logs job/taskflow-migration-<revision>
```

### Check HPA status

```bash
kubectl get hpa
```

### Check PVC status

```bash
kubectl get pvc
```

### Check network policies

```bash
kubectl get networkpolicies
```

## Architecture

```
┌─────────────┐
│   Ingress   │
└──────┬──────┘
       │
       v
┌─────────────┐     ┌──────────────┐
│  API Pods   │────▶│  PostgreSQL  │
│  (HPA/PDB)  │     │ (StatefulSet)│
└──────┬──────┘     └──────────────┘
       │                    ▲
       │                    │
       v                    │
┌─────────────┐             │
│    Redis    │             │
└──────┬──────┘             │
       │                    │
       v                    │
┌─────────────┐             │
│ Worker Pods │─────────────┘
│    (HPA)    │
└─────────────┘

┌─────────────┐
│  CronJob    │
│  (Cleanup)  │
└─────────────┘

┌─────────────┐
│ Migration   │
│  (Job Hook) │
└─────────────┘
```

## Values Files

- `values.yaml`: Production-ready defaults
- `values-kind.yaml`: Minimal resources for local Kind cluster

## License

Copyright 2025 TaskFlow Team
