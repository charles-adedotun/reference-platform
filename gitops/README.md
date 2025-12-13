# GitOps Configuration

Complete ArgoCD-based GitOps configuration for the reference platform.

## Directory Structure

```
gitops/
├── bootstrap/          # Cluster and ArgoCD installation
│   ├── kind-config.yaml
│   └── install-argocd.sh
├── argocd/            # ArgoCD Helm values
│   └── values.yaml
├── root/              # Root Application and ApplicationSets
│   ├── root-app.yaml
│   ├── kustomization.yaml
│   ├── platform-apps.yaml
│   └── workload-apps.yaml
├── platform/          # Platform component kustomizations
│   ├── kyverno/
│   ├── gateway-api-crds/
│   ├── external-secrets/
│   ├── cert-manager/
│   ├── envoy-gateway/
│   ├── kube-prometheus-stack/
│   ├── loki-stack/
│   └── opentelemetry-collector/
└── applications/      # Application kustomizations
    └── taskflow/
```

## Quick Start

### 1. Create Kind Cluster

```bash
cd gitops/bootstrap
kind create cluster --config kind-config.yaml --name reference-platform
```

### 2. Install ArgoCD

```bash
./install-argocd.sh
```

### 3. Deploy Root Application

```bash
kubectl apply -f ../root/root-app.yaml
```

### 4. Access ArgoCD UI

Get admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Access UI:
```bash
# Via NodePort (Kind port mapping)
open http://localhost:30080

# Or via port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
open https://localhost:8080
```

## Platform Components

Platform components are deployed with automated sync in the following order (sync waves):

| Wave | Component | Namespace | Purpose |
|------|-----------|-----------|---------|
| -5 | kyverno | kyverno | Policy engine |
| -4 | gateway-api-crds | gateway-system | Gateway API CRDs |
| -3 | external-secrets | external-secrets | External secrets operator |
| -2 | cert-manager | cert-manager | Certificate management |
| -1 | envoy-gateway | envoy-gateway-system | API gateway |
| 0 | kube-prometheus-stack | monitoring | Prometheus & Grafana |
| 1 | loki-stack | monitoring | Log aggregation |
| 2 | opentelemetry-collector | opentelemetry | Telemetry collection |

## Applications

Applications are deployed with manual sync:

| Wave | Application | Namespace | Sync Policy |
|------|-------------|-----------|-------------|
| 10 | taskflow | taskflow | Manual |

## Port Mappings

Kind cluster exposes the following ports:

- **30080** → ArgoCD UI (NodePort)
- **31000** → Grafana UI (NodePort)
- **32000** → Application API (mapped to 8080)

## Configuration Updates

### Update Before Deployment

1. Update Git repository URL in:
   - `root/root-app.yaml`
   - `root/platform-apps.yaml`
   - `root/workload-apps.yaml`

2. Update container registry in:
   - `applications/taskflow/kustomization.yaml`

### Platform Component Values

Platform components reference Helm values from `/platform/<component>/values-kind.yaml`

### Application Values

Applications reference Helm values from `/apps/<app>/deploy/helm/values-kind.yaml`

## Sync Policies

### Platform Components
- **Sync**: Automated with prune and self-heal
- **Options**: CreateNamespace=true, ServerSideApply=true
- **Retry**: Enabled with exponential backoff

### Applications
- **Sync**: Manual
- **Options**: CreateNamespace=true, ServerSideApply=true
- **Retry**: Enabled with limited retries

## Notes

- ArgoCD is configured for Kind with minimal resource requirements
- Dex and notifications are disabled for simplicity
- ArgoCD server runs in insecure mode (no TLS)
- All platform components use ServerSideApply for better conflict resolution
