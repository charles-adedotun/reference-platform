# System Architecture

This document describes the high-level architecture of the reference platform, including components, data flow, and design decisions.

## Table of Contents

- [Overview](#overview)
- [System Components](#system-components)
- [Architecture Diagrams](#architecture-diagrams)
- [Data Flow](#data-flow)
- [Deployment Architecture](#deployment-architecture)
- [Networking](#networking)
- [Database Architecture](#database-architecture)
- [Caching Strategy](#caching-strategy)
- [Security Architecture](#security-architecture)
- [Design Decisions](#design-decisions)

---

## Overview

The reference platform is a cloud-native, Kubernetes-based system designed for high availability, scalability, and observability. It follows microservices architecture patterns with GitOps-based deployment and comprehensive security controls.

### Key Characteristics

- **Cloud Native**: Built on Kubernetes, containerized, declarative configuration
- **GitOps**: All infrastructure and applications managed via Git
- **Observable**: Comprehensive metrics, logs, and traces
- **Secure**: Security scanning, SBOM generation, policy enforcement
- **Resilient**: High availability, automatic failover, graceful degradation

### Technology Stack

- **Container Orchestration**: Kubernetes (kind for local, managed K8s for prod)
- **GitOps**: ArgoCD / Flux CD
- **Container Runtime**: Docker / containerd
- **Service Mesh**: (Optional) Istio / Linkerd
- **Observability**: Prometheus, Grafana, Jaeger/Tempo, Loki
- **Database**: PostgreSQL with streaming replication
- **Cache**: Redis
- **Message Queue**: (Optional) RabbitMQ / Kafka

---

## System Components

### Application Tier

```
┌─────────────────────────────────────────────────────────┐
│                    Application Services                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │   API    │  │  Worker  │  │   Web    │              │
│  │ Service  │  │ Service  │  │  Front   │              │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘              │
│        │             │              │                    │
│        └─────────────┴──────────────┘                    │
│                      │                                   │
└──────────────────────┼───────────────────────────────────┘
                       │
```

### Platform Tier

```
┌─────────────────────────────────────────────────────────┐
│                   Platform Services                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Ingress │  │  Service │  │   Auth   │              │
│  │   NGINX  │  │   Mesh   │  │  OAuth2  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Data Tier

```
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                          │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │PostgreSQL│  │  Redis   │  │  Object  │              │
│  │ Primary  │  │  Cache   │  │ Storage  │              │
│  └─────┬────┘  └──────────┘  └──────────┘              │
│        │                                                 │
│  ┌─────┴────┐                                           │
│  │PostgreSQL│                                           │
│  │ Standby  │                                           │
│  └──────────┘                                           │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Observability Tier

```
┌─────────────────────────────────────────────────────────┐
│                   Observability Stack                    │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │Prometheus│  │  Loki    │  │  Jaeger  │              │
│  │ Metrics  │  │  Logs    │  │ Traces   │              │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘              │
│        │             │              │                    │
│        └─────────────┴──────────────┘                    │
│                      │                                   │
│              ┌───────┴────────┐                         │
│              │    Grafana     │                         │
│              │  Dashboards    │                         │
│              └────────────────┘                         │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## Architecture Diagrams

### High-Level System Architecture

```
                              ┌──────────────┐
                              │   Internet   │
                              └──────┬───────┘
                                     │
                              ┌──────▼───────┐
                              │   Ingress    │
                              │   (NGINX)    │
                              └──────┬───────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  │                  │                  │
           ┌──────▼─────┐    ┌──────▼─────┐    ┌──────▼─────┐
           │    API     │    │    Web     │    │   Worker   │
           │  Service   │    │  Frontend  │    │  Service   │
           └──────┬─────┘    └──────┬─────┘    └──────┬─────┘
                  │                  │                  │
                  └──────────────────┼──────────────────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  │                  │                  │
           ┌──────▼─────┐    ┌──────▼─────┐    ┌──────▼─────┐
           │ PostgreSQL │    │   Redis    │    │   Object   │
           │  (Primary) │    │   Cache    │    │  Storage   │
           └──────┬─────┘    └────────────┘    └────────────┘
                  │
           ┌──────▼─────┐
           │ PostgreSQL │
           │ (Standby)  │
           └────────────┘
```

### Request Flow

```
1. User Request
   │
   ▼
2. Ingress Controller
   │ (TLS termination, routing)
   ▼
3. Service Mesh (optional)
   │ (mTLS, retries, circuit breaking)
   ▼
4. Application Pod
   │
   ├─► 5a. Cache Check (Redis)
   │   │
   │   ├─► Cache Hit → Return
   │   │
   │   └─► Cache Miss
   │       │
   │       ▼
   └─► 5b. Database Query (PostgreSQL)
       │
       ▼
   6. Return Response
   │
   ▼
7. Update Cache
```

### GitOps Deployment Flow

```
┌──────────────┐
│  Developer   │
│  git push    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Git Repo   │
│  (GitHub)    │
└──────┬───────┘
       │
       ▼
┌──────────────┐        ┌──────────────┐
│   ArgoCD     │───────▶│  Kubernetes  │
│   Sync       │        │   Cluster    │
└──────────────┘        └──────────────┘
       │
       │ (polls every 3min)
       │
       └──────────────────┐
                          ▼
                    ┌──────────────┐
                    │  Manifests   │
                    │   Applied    │
                    └──────────────┘
```

---

## Data Flow

### Write Path

1. **API Request** arrives at ingress
2. **Validation** by application service
3. **Transaction** started in PostgreSQL
4. **Write** to primary database
5. **Streaming Replication** to standby (async)
6. **Cache Invalidation** in Redis
7. **Response** returned to client
8. **Async Processing** (if needed) via worker

### Read Path

1. **API Request** arrives at ingress
2. **Cache Check** in Redis
3. If **Cache Hit**: return immediately
4. If **Cache Miss**:
   - Query PostgreSQL (read from primary or read-replica)
   - Update Redis cache with TTL
   - Return response

### Background Processing

1. **Job Enqueued** (via API or scheduler)
2. **Worker Pod** picks up job
3. **Processing** with retries
4. **Database Update** (if needed)
5. **Cache Update** (if needed)
6. **Job Completion** logged

---

## Deployment Architecture

### Kubernetes Namespaces

```
default                 # Avoid using directly
├── staging             # Staging environment
│   ├── apps
│   ├── data
│   └── monitoring
├── production          # Production environment
│   ├── apps
│   ├── data
│   └── monitoring
├── platform            # Platform services
│   ├── argocd
│   ├── ingress-nginx
│   ├── cert-manager
│   └── external-dns
└── observability       # Monitoring stack
    ├── prometheus
    ├── grafana
    ├── loki
    └── jaeger
```

### Pod Topology

```yaml
# Anti-affinity rules ensure pods spread across nodes
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: myapp
```

### Resource Allocation

```
Production Tier:
- API Service:    3 replicas, 500m CPU, 1Gi RAM each
- Worker Service: 2 replicas, 1000m CPU, 2Gi RAM each
- PostgreSQL:     1 primary + 1 standby, 2000m CPU, 4Gi RAM
- Redis:          1 instance, 500m CPU, 2Gi RAM

Limits set at 2x requests for burstability
```

---

## Networking

### Network Policies

```yaml
# Example: Allow only app pods to access database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-netpol
spec:
  podSelector:
    matchLabels:
      app: postgres
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: app
    ports:
    - protocol: TCP
      port: 5432
```

### Service Types

- **ClusterIP**: Internal services (database, cache)
- **NodePort**: Not used (prefer LoadBalancer)
- **LoadBalancer**: External-facing services (ingress)
- **ExternalName**: External service references

### DNS

```
# Internal DNS resolution
<service-name>.<namespace>.svc.cluster.local

# Examples:
postgres.production.svc.cluster.local
redis.staging.svc.cluster.local
api.production.svc.cluster.local
```

---

## Database Architecture

### PostgreSQL High Availability

```
┌────────────────────────────────────────────────────┐
│                 Primary Node                       │
│  ┌──────────────────────────────────────────┐     │
│  │         PostgreSQL Primary               │     │
│  │     (Reads + Writes)                     │     │
│  └──────────────┬───────────────────────────┘     │
│                 │ WAL Streaming                   │
└─────────────────┼───────────────────────────────────┘
                  │
                  ▼
┌────────────────────────────────────────────────────┐
│                Standby Node                        │
│  ┌──────────────────────────────────────────┐     │
│  │        PostgreSQL Standby                │     │
│  │      (Hot Standby - Reads)               │     │
│  └──────────────────────────────────────────┘     │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Connection Pooling

```
Applications (100 pods × 10 connections = 1000)
              │
              ▼
        ┌──────────┐
        │ PgBouncer│  (Transaction pooling)
        │  Pool: 50│
        └─────┬────┘
              │
              ▼
        PostgreSQL
        max_connections: 100
```

### Backup Strategy

- **Continuous WAL Archiving**: WAL files shipped to S3
- **Daily Base Backups**: Full backup at 02:00 UTC
- **Point-in-Time Recovery**: Up to 30 days
- **Backup Testing**: Monthly restore validation

---

## Caching Strategy

### Redis Architecture

```
┌──────────────────────────────────────────┐
│          Application Tier                │
│   (Cache-Aside Pattern)                  │
└────────────┬─────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│            Redis                       │
│  Mode: Standalone                      │
│  Eviction: allkeys-lru                 │
│  MaxMemory: 2GB                        │
└────────────────────────────────────────┘
```

### Cache Patterns

**Cache-Aside (Lazy Loading)**:
```python
def get_user(user_id):
    # Try cache first
    user = cache.get(f"user:{user_id}")
    if user:
        return user

    # Cache miss - query database
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)

    # Update cache
    cache.setex(f"user:{user_id}", 3600, user)
    return user
```

**Write-Through**:
```python
def update_user(user_id, data):
    # Update database
    db.update("users", user_id, data)

    # Update cache immediately
    cache.setex(f"user:{user_id}", 3600, data)
```

### Cache Key Patterns

```
user:{id}                   # User data
session:{session_id}        # Session data
api:rate:{ip}:{endpoint}    # Rate limiting
query:{hash}                # Query result cache
config:feature_flags        # Feature flags
```

---

## Security Architecture

### Defense in Depth

```
Layer 1: Network Security
  - Network Policies
  - Private subnets
  - Firewall rules

Layer 2: Pod Security
  - Pod Security Standards
  - Security Context
  - Non-root containers
  - Read-only root filesystem

Layer 3: Application Security
  - Input validation
  - Output encoding
  - Authentication/Authorization
  - Secrets management

Layer 4: Data Security
  - Encryption at rest
  - Encryption in transit (TLS)
  - Database access controls
  - Audit logging
```

### Secrets Management

```
┌──────────────┐
│  Developer   │
│              │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ External     │
│ Secrets      │  (Vault, AWS Secrets Manager)
│ Manager      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Kubernetes   │
│ Secrets      │  (Encrypted at rest)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Application  │
│ Environment  │
│ Variables    │
└──────────────┘
```

### RBAC Structure

```yaml
# ServiceAccount for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa

---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- kind: ServiceAccount
  name: app-sa
```

---

## Design Decisions

### Why Kubernetes?

**Benefits**:
- Industry standard for container orchestration
- Declarative configuration
- Self-healing capabilities
- Horizontal scaling
- Rich ecosystem

**Trade-offs**:
- Complexity vs simpler alternatives
- Learning curve
- Operational overhead

**Decision**: Benefits outweigh complexity for our scale and requirements.

### Why GitOps?

**Benefits**:
- Single source of truth (Git)
- Audit trail of all changes
- Easy rollback
- Declarative desired state
- Security through PR reviews

**Trade-offs**:
- Sync delay (3-5 minutes)
- Complexity for urgent changes

**Decision**: GitOps provides better control and auditability.

### Why PostgreSQL?

**Benefits**:
- ACID compliance
- Mature ecosystem
- Strong consistency
- Rich feature set (JSON, full-text search)
- Good performance

**Alternatives Considered**:
- MySQL: Less robust JSON support
- MongoDB: Eventual consistency concerns
- CockroachDB: Overkill for current scale

**Decision**: PostgreSQL meets requirements with proven reliability.

### Why Redis?

**Benefits**:
- Extremely fast (in-memory)
- Rich data structures
- Simple to operate
- Good client library support

**Alternatives Considered**:
- Memcached: Less feature-rich
- Hazelcast: More complex

**Decision**: Redis provides best balance of speed and features.

### Monolith vs Microservices

**Current Approach**: Modular Monolith

**Rationale**:
- Simpler to develop and deploy
- Easier to maintain consistency
- Lower operational overhead
- Can extract microservices later if needed

**Future**: May extract services based on:
- Different scaling needs
- Team boundaries
- Technology requirements

---

## Scalability Considerations

### Horizontal Scaling

- **Application Tier**: Stateless, can scale to 100+ pods
- **Database Tier**: Read replicas for read scaling
- **Cache Tier**: Redis Cluster for data sharding (future)

### Vertical Scaling

- **Database**: Can scale to larger instance types
- **Cache**: Can increase memory allocation

### Auto-scaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Performance Targets

### SLOs (Service Level Objectives)

- **Availability**: 99.9% (43.2 minutes downtime/month)
- **Latency**: P95 < 200ms, P99 < 500ms
- **Error Rate**: < 0.1% of requests
- **Throughput**: 10,000 requests/second

### Resource Limits

- **CPU**: 2x oversubscription ratio
- **Memory**: 1.5x oversubscription ratio
- **Storage**: 80% utilization threshold

---

## Disaster Recovery

### RTO/RPO

- **Recovery Time Objective (RTO)**: 15 minutes
- **Recovery Point Objective (RPO)**: 5 minutes

### Backup Locations

- **Primary Region**: us-west-2
- **Backup Region**: us-east-1
- **Disaster Recovery**: Multi-region capable

### Runbooks

See [../runbooks/](../runbooks/) for operational procedures.

---

## References

- [Deployment Guide](./deployment.md)
- [Observability Guide](./observability.md)
- [Security Guide](./security.md)
- [SLSA Provenance](./slsa-provenance.md)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [The Twelve-Factor App](https://12factor.net/)
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
