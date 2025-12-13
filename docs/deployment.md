# Deployment Guide

Complete guide for deploying the reference platform to local, staging, and production environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Deployment to Staging](#deployment-to-staging)
- [Deployment to Production](#deployment-to-production)
- [GitOps Workflow](#gitops-workflow)
- [Rolling Updates](#rolling-updates)
- [Rollback Procedures](#rollback-procedures)
- [Blue-Green Deployment](#blue-green-deployment)
- [Database Migrations](#database-migrations)
- [Configuration Management](#configuration-management)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Run the setup script to verify all prerequisites:

```bash
./scripts/setup-local.sh
```

Required tools:
- Docker (>= 20.10) or Podman
- kubectl (>= 1.24)
- kind (>= 0.17) for local clusters
- helm (>= 3.10)
- kustomize (>= 4.5)
- argocd CLI (>= 2.5)
- git (>= 2.30)
- jq (>= 1.6)
- yq (>= 4.20)

### Optional Tools

- syft - SBOM generation
- trivy - Security scanning
- cosign - Image signing
- k9s - Cluster management UI

### Access Requirements

- GitHub repository access
- Container registry credentials
- Kubernetes cluster access (for staging/production)
- AWS/GCP/Azure credentials (if using cloud provider)

---

## Local Development Setup

### Step 1: Create Local Kubernetes Cluster

```bash
# Create kind cluster with custom configuration
cat <<EOF | kind create cluster --name reference-platform --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

### Step 2: Install Platform Components

```bash
# Create namespaces
kubectl create namespace staging
kubectl create namespace production
kubectl create namespace platform
kubectl create namespace observability

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Install cert-manager (for TLS certificates)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=90s
```

### Step 3: Install Observability Stack

```bash
# Add Prometheus community helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin

# Verify installation
kubectl get pods -n observability

# Access Grafana
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin/admin)
```

### Step 4: Install ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# Port-forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login with argocd CLI
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Open https://localhost:8080
```

### Step 5: Deploy Applications

```bash
# Apply GitOps applications
kubectl apply -f gitops/argocd/apps/

# Or using argocd CLI
argocd app create reference-platform \
  --repo https://github.com/your-org/reference-platform \
  --path gitops/staging \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# Watch deployment
argocd app get reference-platform
argocd app sync reference-platform

# Or watch in kubectl
kubectl get pods -n staging -w
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n staging

# Check services
kubectl get svc -n staging

# Check ingress
kubectl get ingress -n staging

# Test application endpoint
curl http://localhost/health
```

---

## Deployment to Staging

### Prerequisites

1. Access to staging Kubernetes cluster
2. GitHub repository access
3. Container registry credentials configured

### Step 1: Configure kubectl Context

```bash
# Set kubectl context to staging
kubectl config use-context staging-cluster

# Verify context
kubectl config current-context

# Verify access
kubectl get nodes
```

### Step 2: Configure Container Registry

```bash
# Create registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  --namespace=staging

# Verify secret
kubectl get secret regcred -n staging
```

### Step 3: Deploy via GitOps

```bash
# ArgoCD automatically syncs from Git repository
# Ensure your changes are committed and pushed

git add .
git commit -m "Update staging configuration"
git push origin main

# ArgoCD will detect changes within 3 minutes
# Or manually trigger sync
argocd app sync staging-apps

# Watch deployment
argocd app get staging-apps
kubectl get pods -n staging -w
```

### Step 4: Run Smoke Tests

```bash
# Test health endpoint
curl https://staging.example.com/health

# Test API endpoint
curl https://staging.example.com/api/v1/status

# Check metrics
curl https://staging.example.com/metrics

# Run integration tests
kubectl run test-runner --rm -it --restart=Never \
  --image=test-image:latest \
  -- pytest tests/integration/
```

---

## Deployment to Production

### Prerequisites

1. Successful staging deployment
2. All tests passing
3. Security scans passed
4. Change approval (if required)
5. Runbooks reviewed

### Step 1: Pre-Deployment Checklist

```bash
# Verify staging is healthy
kubectl get pods -n staging
kubectl top pods -n staging

# Run final tests
./scripts/run-tests.sh staging

# Security scan
./scripts/run-trivy.sh myapp:v1.2.3

# Generate SBOM
./scripts/generate-sbom.sh myapp:v1.2.3

# Backup production database
kubectl exec -n production postgres-0 -- \
  pg_dump -U postgres -Fc mydb > backup-$(date +%Y%m%d-%H%M%S).dump
```

### Step 2: Update Production Configuration

```bash
# Update version in gitops/production/kustomization.yaml
cd gitops/production
kustomize edit set image myapp:v1.2.3

# Commit changes
git add .
git commit -m "Production deployment: v1.2.3"
git push origin main
```

### Step 3: Deploy to Production

```bash
# Switch to production context
kubectl config use-context production-cluster

# Sync with ArgoCD
argocd app sync production-apps --prune

# Watch deployment progress
kubectl rollout status deployment/myapp -n production

# Monitor for issues
kubectl get pods -n production -w
kubectl get events -n production --watch
```

### Step 4: Verify Production Deployment

```bash
# Check pod status
kubectl get pods -n production

# Check service endpoints
kubectl get svc -n production

# Test health
curl https://api.example.com/health

# Check metrics
kubectl top pods -n production

# Monitor error rates in Grafana
# Alert on SLO violations
```

### Step 5: Post-Deployment Validation

```bash
# Run smoke tests
./scripts/smoke-test.sh production

# Check application logs
kubectl logs -n production -l app=myapp --tail=100

# Monitor for 15 minutes
# Watch error rates, latency, throughput

# Verify database connections
kubectl exec -n production postgres-0 -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check Redis
kubectl exec -n production redis-0 -- redis-cli INFO stats
```

---

## GitOps Workflow

### Standard Workflow

```
1. Developer creates branch
   git checkout -b feature/my-feature

2. Make changes to code and manifests

3. Commit and push
   git add .
   git commit -m "Add feature X"
   git push origin feature/my-feature

4. Create Pull Request
   - CI/CD runs tests
   - Security scans
   - Review required

5. Merge to main
   - Triggers build
   - Pushes image to registry
   - Updates staging manifests

6. ArgoCD syncs staging
   - Detects changes in Git
   - Applies to staging cluster

7. Promote to production
   - Update production manifests
   - Create PR for production
   - Review and approve
   - Merge triggers production deployment
```

### Directory Structure

```
gitops/
├── base/                 # Base manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── staging/             # Staging overlays
│   ├── kustomization.yaml
│   ├── replicas.yaml
│   └── ingress.yaml
└── production/          # Production overlays
    ├── kustomization.yaml
    ├── replicas.yaml
    └── ingress.yaml
```

### Kustomize Example

```yaml
# gitops/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

images:
- name: myapp
  newName: registry.example.com/myapp
  newTag: latest

---
# gitops/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../base

replicas:
- name: myapp
  count: 5

images:
- name: myapp
  newTag: v1.2.3

patchesStrategicMerge:
- replicas.yaml
- ingress.yaml
```

---

## Rolling Updates

### Default Rolling Update Strategy

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Max 1 pod unavailable during update
      maxSurge: 1        # Max 1 extra pod during update
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:v1.2.3
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Monitoring Rolling Update

```bash
# Start rolling update
kubectl set image deployment/myapp myapp=myapp:v1.2.3 -n production

# Watch rollout
kubectl rollout status deployment/myapp -n production

# Pause rollout (if issues detected)
kubectl rollout pause deployment/myapp -n production

# Resume rollout
kubectl rollout resume deployment/myapp -n production

# Check rollout history
kubectl rollout history deployment/myapp -n production
```

---

## Rollback Procedures

### Quick Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/myapp -n production

# Rollback to specific revision
kubectl rollout undo deployment/myapp -n production --to-revision=3

# Check rollout status
kubectl rollout status deployment/myapp -n production

# Verify rollback
kubectl get pods -n production
kubectl describe deployment myapp -n production
```

### GitOps Rollback

```bash
# Revert Git commit
git revert HEAD
git push origin main

# ArgoCD will auto-sync the revert
# Or manually sync
argocd app sync production-apps

# Verify
kubectl get pods -n production
```

### Emergency Rollback

```bash
# If GitOps is broken, manual rollback
kubectl set image deployment/myapp \
  myapp=myapp:v1.2.2 \
  -n production \
  --record

# Scale down if needed
kubectl scale deployment/myapp --replicas=0 -n production

# Wait, then scale back up
kubectl scale deployment/myapp --replicas=5 -n production
```

---

## Blue-Green Deployment

### Setup

```yaml
# Blue deployment (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: blue

---
# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: green

---
# Service (switch between blue and green)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue  # Currently pointing to blue
  ports:
  - port: 80
    targetPort: 8080
```

### Deployment Process

```bash
# 1. Deploy green version
kubectl apply -f deployment-green.yaml

# 2. Wait for green to be ready
kubectl rollout status deployment/myapp-green -n production

# 3. Test green version
kubectl port-forward deployment/myapp-green 9000:8080
curl http://localhost:9000/health

# 4. Switch traffic to green
kubectl patch service myapp -n production \
  -p '{"spec":{"selector":{"version":"green"}}}'

# 5. Monitor green in production
# Watch metrics, logs, errors

# 6. If successful, delete blue
kubectl delete deployment myapp-blue -n production

# 7. If issues, rollback to blue
kubectl patch service myapp -n production \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## Database Migrations

### Migration Strategy

```bash
# 1. Test migration in staging
kubectl exec -n staging postgres-0 -- \
  psql -U postgres -d mydb -f /migrations/001_add_column.sql

# 2. Backup production database
kubectl exec -n production postgres-0 -- \
  pg_dump -U postgres -Fc mydb > backup-pre-migration.dump

# 3. Run migration in production (during maintenance window)
kubectl exec -n production postgres-0 -- \
  psql -U postgres -d mydb -f /migrations/001_add_column.sql

# 4. Verify migration
kubectl exec -n production postgres-0 -- \
  psql -U postgres -d mydb -c "\d table_name"
```

### Zero-Downtime Migrations

```sql
-- Step 1: Add new column (nullable)
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- Deploy application version that writes to both columns
-- Wait for all instances to be updated

-- Step 2: Backfill data
UPDATE users SET email = old_email WHERE email IS NULL;

-- Step 3: Make column NOT NULL
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Deploy application version that uses new column
-- Wait for all instances to be updated

-- Step 4: Drop old column
ALTER TABLE users DROP COLUMN old_email;
```

---

## Configuration Management

### ConfigMaps

```bash
# Create ConfigMap from file
kubectl create configmap app-config \
  --from-file=config.yaml \
  -n production

# Update ConfigMap
kubectl create configmap app-config \
  --from-file=config.yaml \
  -n production \
  --dry-run=client -o yaml | kubectl apply -f -

# Rollout restart to pick up new config
kubectl rollout restart deployment/myapp -n production
```

### Secrets

```bash
# Create secret
kubectl create secret generic app-secrets \
  --from-literal=db-password=secret123 \
  --from-literal=api-key=key456 \
  -n production

# Update secret
kubectl create secret generic app-secrets \
  --from-literal=db-password=newsecret \
  --dry-run=client -o yaml | kubectl apply -f -

# Rollout restart
kubectl rollout restart deployment/myapp -n production
```

### Environment-Specific Configuration

```yaml
# Use Kustomize for environment-specific configs
# gitops/production/config-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  REPLICAS: "5"
  CACHE_TTL: "3600"
```

---

## Troubleshooting

### Deployment Stuck

```bash
# Check deployment status
kubectl describe deployment myapp -n production

# Check pod status
kubectl get pods -n production -l app=myapp

# Check pod events
kubectl describe pod <pod-name> -n production

# Check logs
kubectl logs <pod-name> -n production

# Check previous logs (if crashlooping)
kubectl logs <pod-name> -n production --previous
```

### Image Pull Errors

```bash
# Check image pull secret
kubectl get secret regcred -n production

# Test image pull manually
docker pull registry.example.com/myapp:v1.2.3

# Recreate secret if needed
kubectl delete secret regcred -n production
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=<username> \
  --docker-password=<password> \
  -n production
```

### Pod Not Ready

```bash
# Check readiness probe
kubectl describe pod <pod-name> -n production | grep -A 10 Readiness

# Test probe manually
kubectl exec <pod-name> -n production -- curl http://localhost:8080/health

# Check application logs
kubectl logs <pod-name> -n production

# Increase probe timeouts if slow to start
```

### ArgoCD Sync Issues

```bash
# Check app status
argocd app get production-apps

# Check sync status
argocd app sync production-apps --dry-run

# Hard refresh
argocd app get production-apps --hard-refresh

# Delete and recreate app
argocd app delete production-apps
argocd app create production-apps --file app.yaml
```

---

## References

- [Architecture Documentation](./architecture.md)
- [Observability Guide](./observability.md)
- [Security Guide](./security.md)
- [Runbooks](../runbooks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
