# Reference Platform

A production-style, end-to-end Kubernetes reference platform for DevOps/SRE evaluation.

[![CI](https://github.com/charles-adedotun/reference-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/charles-adedotun/reference-platform/actions/workflows/ci.yml)
[![Security](https://github.com/charles-adedotun/reference-platform/actions/workflows/security.yml/badge.svg)](https://github.com/charles-adedotun/reference-platform/actions/workflows/security.yml)

## Quick Evaluation (3-5 minutes)

### Prerequisites

```bash
# Required tools
docker --version    # Docker 24+
kind --version      # Kind 0.20+
kubectl version     # Kubectl 1.28+
helm version        # Helm 3.12+
```

### Local Demo

```bash
# 1. Create Kind cluster with ArgoCD and platform components
make kind-up

# 2. Wait for platform and deploy TaskFlow app
make demo

# 3. Verify endpoints work
make smoke
# Expected output:
#   /health: 200 OK (15ms)
#   /api/v1/transaction: 200 OK (145ms)

# 4. Access UIs
#    ArgoCD:  http://localhost:30080
#    Grafana: http://localhost:31000
#    API:     http://localhost:8080

# 5. (Optional) Failure injection demo
make break-db    # Kill Postgres pod
make smoke       # Should fail
make fix-db      # Recover
make smoke       # Should pass

# 6. Cleanup
make kind-down
```

### Cloud Deploy Path (Terraform)

```bash
# AWS EKS deployment (plan only - does NOT auto-apply)
cd infra/terraform/environments/aws/dev
terraform init
terraform plan

# GCP GKE deployment
cd infra/terraform/environments/gcp/dev
terraform init
terraform plan
```

### What You Should See

| Component | URL | Credentials |
|-----------|-----|-------------|
| ArgoCD | http://localhost:30080 | admin / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Grafana | http://localhost:31000 | admin / admin |
| TaskFlow API | http://localhost:8080 | N/A |
| Prometheus | http://localhost:9090 (via port-forward) | N/A |

## Platform Stack

### Infrastructure (Terraform)

| Component | Description |
|-----------|-------------|
| Network | VPC, subnets, NAT gateway, security groups |
| Kubernetes | EKS (AWS) / GKE (GCP) with managed node groups |
| IAM/OIDC | GitHub Actions keyless authentication |
| State Backend | S3 with native locking (AWS) / GCS (GCP) |

### GitOps (ArgoCD)

App-of-apps pattern with sync waves:

| Wave | Component |
|------|-----------|
| -5 | Kyverno policies |
| -4 | Gateway API CRDs |
| -3 | External Secrets Operator |
| -2 | Cert-Manager |
| -1 | Envoy Gateway |
| 0 | Kube-Prometheus-Stack |
| 1 | Loki Stack |
| 2 | OpenTelemetry Collector |
| 10 | TaskFlow application |

### Observability

- **Metrics**: Prometheus + Alertmanager + Grafana
- **Logs**: Loki + Promtail
- **Traces**: OpenTelemetry Collector (debug exporter locally)
- **Correlation**: Logs include `trace_id` and `span_id` for cross-referencing

### Security

| Tool | Purpose |
|------|---------|
| Kyverno | Policy enforcement (5 baseline policies) |
| CodeQL | Static code analysis |
| Trivy | Container vulnerability scanning |
| gitleaks | Secret detection |
| Dependabot | Dependency updates |
| Syft | SBOM generation |
| cosign | Image signing |

### Sample Application (TaskFlow)

A realistic microservices demo:

- **API Service**: REST endpoints for task management
- **Worker Service**: Async job processor (Redis queue)
- **Cron Job**: Scheduled cleanup
- **PostgreSQL**: Persistent storage
- **Redis**: Queue and caching

Endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Liveness probe |
| `/ready` | GET | Readiness probe (checks DB + Redis) |
| `/api/v1/tasks` | GET/POST | Task CRUD |
| `/api/v1/tasks/{id}` | GET/PUT/DELETE | Single task operations |
| `/api/v1/transaction` | POST | Synthetic monitoring endpoint |

## Repository Structure

```
reference-platform/
├── infra/terraform/          # Infrastructure as Code
│   ├── modules/              # Reusable Terraform modules
│   ├── environments/         # dev/staging/prod configs
│   └── bootstrap/            # State backend setup
├── platform/                 # Cluster add-ons
│   ├── kyverno/              # Policy-as-code
│   ├── kube-prometheus-stack/
│   ├── loki-stack/
│   └── ...
├── apps/taskflow/            # Sample application
│   ├── cmd/                  # Go entrypoints
│   ├── internal/             # Business logic
│   └── deploy/helm/          # Helm chart
├── gitops/                   # ArgoCD configuration
│   ├── bootstrap/            # Kind + ArgoCD setup
│   ├── root/                 # App-of-apps
│   └── platform/             # Platform apps
├── .github/workflows/        # CI/CD pipelines
├── runbooks/                 # Operational runbooks
├── postmortems/              # Incident documentation
├── scripts/                  # Utility scripts
└── docs/                     # Documentation
```

## Makefile Targets

```bash
# Quick evaluation
make kind-up       # Create Kind cluster + ArgoCD + platform
make kind-down     # Delete Kind cluster
make demo          # Deploy app and wait for ready
make smoke         # Verify /health and /api/v1/transaction

# Development
make lint          # Run linters (Go, YAML, Terraform)
make test          # Run unit tests
make build         # Build Docker images locally

# Security
make sbom          # Generate SBOM with Syft
make scan          # Run Trivy vulnerability scan
make gitleaks      # Scan for secrets

# Operations
make break-db      # Inject database failure
make fix-db        # Recover from failure

# Terraform
make tf-plan       # terraform plan (AWS dev)
make tf-apply      # terraform apply (requires confirmation)
```

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Observability](docs/observability.md)
- [Security Practices](docs/security.md)
- [SLSA Provenance](docs/slsa-provenance.md)

## Runbooks

Alert-to-runbook mapping and operational procedures:

- [High CPU Usage](runbooks/high-cpu-usage.md)
- [Database Connection Exhausted](runbooks/database-connection-exhausted.md)
- [Redis Memory Full](runbooks/redis-memory-full.md)
- [Pod CrashLoop](runbooks/pod-crashloop.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.

## License

Apache 2.0 - See [LICENSE](LICENSE)
