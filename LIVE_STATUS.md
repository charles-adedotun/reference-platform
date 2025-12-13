# Live Status Dashboard

**Last Updated:** 2025-01-15 14:30:00 UTC

## Cluster Health

| Component | Status | Version | Uptime |
|-----------|--------|---------|--------|
| Kubernetes API | Healthy | v1.31.0 | 7d 14h 23m |
| ArgoCD | Healthy | v2.13.2 | 7d 14h 18m |
| API Service | Healthy | v1.0.0 | 2d 8h 45m |
| PostgreSQL | Healthy | 15.10 | 7d 14h 15m |

## Application Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| API Response Time (p95) | 45ms | <100ms | OK |
| API Success Rate | 99.95% | >99.9% | OK |
| Database Connection Pool | 8/20 | <80% | OK |
| Active Connections | 156 | <1000 | OK |
| Memory Usage (API) | 245MB | <512MB | OK |
| CPU Usage (API) | 12% | <70% | OK |

## Recent Deployments

| Application | Version | Deployed At | Status |
|-------------|---------|-------------|--------|
| api | v1.0.0 | 2025-01-13 09:15:00 UTC | Success |
| postgres | 15.10 | 2025-01-08 08:00:00 UTC | Success |

## Sync Status (ArgoCD)

| Application | Sync Status | Health | Last Sync |
|-------------|-------------|--------|-----------|
| root | Synced | Healthy | 2025-01-15 14:25:00 UTC |
| api | Synced | Healthy | 2025-01-13 09:15:00 UTC |
| postgres | Synced | Healthy | 2025-01-08 08:00:00 UTC |

## Incidents

| Date | Severity | Summary | Status | Duration |
|------|----------|---------|--------|----------|
| 2025-01-10 | Minor | API pod restart due to OOM | Resolved | 2m 15s |
| 2025-01-05 | Critical | Database connection pool exhaustion | Resolved | 8m 42s |

## Resource Usage

### API Service
- **Pods:** 3/3 Ready
- **CPU:** 0.12 cores / 0.5 limit (24%)
- **Memory:** 245Mi / 512Mi (48%)
- **Restarts:** 0 (last 24h)

### PostgreSQL
- **Pods:** 1/1 Ready
- **CPU:** 0.08 cores / 0.5 limit (16%)
- **Memory:** 156Mi / 1Gi (15%)
- **Storage:** 2.3Gi / 10Gi (23%)

## Health Endpoints

| Endpoint | Status | Response Time | Last Check |
|----------|--------|---------------|------------|
| /health | 200 OK | 5ms | 2025-01-15 14:30:00 UTC |
| /ready | 200 OK | 8ms | 2025-01-15 14:30:00 UTC |
| /api/v1/transaction | 200 OK | 42ms | 2025-01-15 14:30:00 UTC |

## Database Metrics

| Metric | Value |
|--------|-------|
| Active Connections | 8 |
| Idle Connections | 12 |
| Transactions/sec | 145 |
| Cache Hit Ratio | 99.2% |
| Database Size | 2.3 GB |
| Table Count | 15 |

## Network

| Metric | Value |
|--------|-------|
| Ingress Requests/min | 2,340 |
| Egress Data Rate | 1.2 MB/s |
| Active Connections | 156 |
| 5xx Error Rate | 0.02% |

## Alerts (Active)

*No active alerts*

## SLO Compliance (Last 30 Days)

| SLO | Target | Actual | Status |
|-----|--------|--------|--------|
| API Availability | 99.9% | 99.95% | Met |
| P95 Response Time | <100ms | 47ms | Met |
| Error Rate | <0.1% | 0.05% | Met |

---

*This dashboard is automatically updated every 5 minutes.*
*Data source: Prometheus + ArgoCD API*
