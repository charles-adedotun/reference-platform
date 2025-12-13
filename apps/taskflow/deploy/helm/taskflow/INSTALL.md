# TaskFlow Helm Chart Installation Guide

## Quick Start

### 1. Production Installation

Deploy TaskFlow with production-ready defaults:

```bash
# Install the chart
helm install taskflow ./taskflow --namespace taskflow --create-namespace

# Check deployment status
kubectl get pods -n taskflow

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=taskflow -n taskflow --timeout=300s
```

### 2. Kind/Local Development Installation

Deploy TaskFlow with minimal resources for local development:

```bash
# Install with Kind values
helm install taskflow ./taskflow -f values-kind.yaml --namespace taskflow --create-namespace

# Access the API via NodePort
export NODE_PORT=32000
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo "TaskFlow API: http://$NODE_IP:$NODE_PORT"

# Or use port forwarding
kubectl port-forward -n taskflow svc/taskflow-api 8000:8000
echo "TaskFlow API: http://localhost:8000"
```

## Step-by-Step Installation

### Prerequisites

1. **Install Helm 3+**
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

2. **Verify Kubernetes cluster access**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Create namespace (optional)**
   ```bash
   kubectl create namespace taskflow
   ```

### Installation Options

#### Option 1: Default Production Deployment

```bash
helm install taskflow ./taskflow \
  --namespace taskflow \
  --create-namespace
```

#### Option 2: Custom Values File

Create a custom values file:

```yaml
# my-values.yaml
api:
  replicaCount: 5
  service:
    type: LoadBalancer
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi

postgresql:
  persistence:
    storageClass: "fast-ssd"
    size: 20Gi

telemetry:
  enabled: true
  endpoint: "http://otel-collector.observability:4317"
```

Install with custom values:

```bash
helm install taskflow ./taskflow \
  -f my-values.yaml \
  --namespace taskflow \
  --create-namespace
```

#### Option 3: Override Individual Values

```bash
helm install taskflow ./taskflow \
  --set api.replicaCount=5 \
  --set worker.replicaCount=10 \
  --set postgresql.persistence.size=20Gi \
  --namespace taskflow \
  --create-namespace
```

#### Option 4: Disable Components

```bash
# Use external PostgreSQL and Redis
helm install taskflow ./taskflow \
  --set postgresql.enabled=false \
  --set redis.enabled=false \
  --set-string env[0].name=DATABASE_URL \
  --set-string env[0].value="postgresql://user:pass@external-db:5432/taskflow" \
  --set-string env[1].name=REDIS_URL \
  --set-string env[1].value="redis://external-redis:6379/0" \
  --namespace taskflow \
  --create-namespace
```

## Post-Installation

### Verify Installation

```bash
# Check all resources
kubectl get all -n taskflow

# Check pods
kubectl get pods -n taskflow -o wide

# Check services
kubectl get svc -n taskflow

# Check PVCs
kubectl get pvc -n taskflow

# Check HPAs
kubectl get hpa -n taskflow
```

### Check Migration Status

```bash
# List migration jobs
kubectl get jobs -n taskflow -l app.kubernetes.io/component=migration

# Check migration logs
kubectl logs -n taskflow job/taskflow-migration-1
```

### Access the Application

#### For NodePort (Kind/Local):

```bash
export NODE_PORT=$(kubectl get svc taskflow-api -n taskflow -o jsonpath='{.spec.ports[0].nodePort}')
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
curl http://$NODE_IP:$NODE_PORT/health
```

#### For ClusterIP (with port-forward):

```bash
kubectl port-forward -n taskflow svc/taskflow-api 8000:8000 &
curl http://localhost:8000/health
```

#### For LoadBalancer:

```bash
export SERVICE_IP=$(kubectl get svc taskflow-api -n taskflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$SERVICE_IP:8000/health
```

### Monitor Logs

```bash
# API logs
kubectl logs -f -n taskflow -l app.kubernetes.io/component=api

# Worker logs
kubectl logs -f -n taskflow -l app.kubernetes.io/component=worker

# PostgreSQL logs
kubectl logs -f -n taskflow -l app.kubernetes.io/component=postgresql

# All TaskFlow logs
kubectl logs -f -n taskflow -l app.kubernetes.io/name=taskflow
```

## Upgrades

### Standard Upgrade

```bash
# Update the chart
helm upgrade taskflow ./taskflow -n taskflow

# Upgrade with new values
helm upgrade taskflow ./taskflow -f my-values.yaml -n taskflow
```

### Zero-Downtime Upgrade

The chart is configured for zero-downtime upgrades:
- PodDisruptionBudget ensures minimum availability
- Rolling updates are configured by default
- Pre-upgrade migration hook runs automatically

```bash
# Upgrade with extended timeout
helm upgrade taskflow ./taskflow \
  -n taskflow \
  --timeout 10m \
  --wait
```

### Rollback

```bash
# List releases
helm history taskflow -n taskflow

# Rollback to previous version
helm rollback taskflow -n taskflow

# Rollback to specific revision
helm rollback taskflow 2 -n taskflow
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n taskflow

# Check events
kubectl get events -n taskflow --sort-by='.lastTimestamp'

# Check resource constraints
kubectl top nodes
kubectl top pods -n taskflow
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl logs -n taskflow -l app.kubernetes.io/component=postgresql

# Test connection from API pod
kubectl exec -it -n taskflow <api-pod> -- \
  psql -h taskflow-postgresql -U taskflow -d taskflow -c '\dt'
```

### Migration Failures

```bash
# Check migration job
kubectl describe job -n taskflow -l app.kubernetes.io/component=migration

# View migration logs
kubectl logs -n taskflow job/taskflow-migration-<revision>

# Delete failed migration job and retry
kubectl delete job -n taskflow -l app.kubernetes.io/component=migration
helm upgrade taskflow ./taskflow -n taskflow
```

### Network Policy Issues

```bash
# Check network policies
kubectl get networkpolicies -n taskflow

# Temporarily disable network policies for debugging
helm upgrade taskflow ./taskflow \
  --set networkPolicy.enabled=false \
  -n taskflow
```

## Uninstallation

### Clean Uninstall

```bash
# Uninstall the release
helm uninstall taskflow -n taskflow

# Delete PVCs (if needed)
kubectl delete pvc -n taskflow -l app.kubernetes.io/name=taskflow

# Delete namespace
kubectl delete namespace taskflow
```

### Preserve Data

```bash
# Uninstall but keep PVCs
helm uninstall taskflow -n taskflow

# PVCs remain for future reinstallation
kubectl get pvc -n taskflow
```

## Common Configurations

### High Availability Setup

```yaml
# ha-values.yaml
api:
  replicaCount: 5
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 20
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

worker:
  replicaCount: 10
  autoscaling:
    enabled: true
    minReplicas: 10
    maxReplicas: 50

postgresql:
  persistence:
    enabled: true
    size: 50Gi
```

### Development Setup

```yaml
# dev-values.yaml
api:
  replicaCount: 1
  autoscaling:
    enabled: false
  service:
    type: NodePort
    nodePort: 32000

worker:
  replicaCount: 1
  autoscaling:
    enabled: false

postgresql:
  persistence:
    enabled: false

redis:
  persistence:
    enabled: false

networkPolicy:
  enabled: false
```

### Resource-Constrained Environment

```yaml
# minimal-values.yaml
api:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: false

worker:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  autoscaling:
    enabled: false

postgresql:
  persistence:
    size: 1Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

redis:
  persistence:
    size: 1Gi
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
```

## Support

For issues and questions:
- GitHub: https://github.com/taskflow/taskflow/issues
- Documentation: https://docs.taskflow.io
