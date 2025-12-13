# Database Connection Pool Exhausted Runbook

## Overview
- **Alert**: DatabaseConnectionPoolExhausted / DatabaseConnectionsHigh
- **Severity**: Critical / Warning
- **Service Impact**: Database queries failing, application errors, service degradation

## Symptoms

- Alert firing: `DatabaseConnectionPoolExhausted` or `DatabaseConnectionsHigh`
- Application logs showing connection timeout errors
- Database connection errors in application metrics
- Slow or failing database queries
- Error messages: "too many connections", "connection pool exhausted"

## Investigation

### 1. Check Current Database Connections

```bash
# Connect to PostgreSQL pod
kubectl exec -it <postgres-pod-name> -n <namespace> -- psql -U <username> -d <database>

# Inside psql - check current connections
SELECT count(*) as connection_count FROM pg_stat_activity;

# View connections by state
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state;

# View connections by application
SELECT application_name, count(*)
FROM pg_stat_activity
GROUP BY application_name;

# View all active connections with details
SELECT
  pid,
  usename,
  application_name,
  client_addr,
  state,
  query_start,
  state_change,
  wait_event_type,
  wait_event,
  LEFT(query, 50) as query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
```

### 2. Check Connection Limits

```bash
# Inside psql - check max connections setting
SHOW max_connections;

# Check current database settings
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN ('max_connections', 'superuser_reserved_connections');

# Exit psql
\q
```

### 3. Check Application Connection Pool Settings

```bash
# View application deployment environment variables
kubectl get deployment <app-deployment> -n <namespace> -o yaml | grep -A 20 "env:"

# Check for connection pool settings (common env vars)
kubectl get deployment <app-deployment> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].env[?(@.name=="DB_POOL_SIZE")].value}'
kubectl get deployment <app-deployment> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].env[?(@.name=="DB_MAX_CONNECTIONS")].value}'
```

### 4. Check Application Logs

```bash
# Check for connection errors
kubectl logs -n <namespace> -l app=<app-label> --tail=200 | grep -i "connection\|pool\|database"

# Check for connection leak patterns
kubectl logs -n <namespace> -l app=<app-label> --tail=500 | grep -i "timeout\|exhausted\|too many"

# Get logs from all pods
for pod in $(kubectl get pods -n <namespace> -l app=<app-label> -o name); do
  echo "=== $pod ==="
  kubectl logs -n <namespace> $pod --tail=50 | grep -i "connection"
done
```

### 5. Check for Long-Running Queries

```bash
# Connect to database
kubectl exec -it <postgres-pod-name> -n <namespace> -- psql -U <username> -d <database>

# Inside psql - find long-running queries
SELECT
  pid,
  now() - query_start as duration,
  state,
  query
FROM pg_stat_activity
WHERE state != 'idle'
  AND now() - query_start > interval '1 minute'
ORDER BY duration DESC;

# Check for locks
SELECT
  blocked_locks.pid AS blocked_pid,
  blocked_activity.usename AS blocked_user,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_statement,
  blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
  ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### 6. Check Pod Scaling

```bash
# Check number of application replicas
kubectl get deployment <app-deployment> -n <namespace>

# Check pod count
kubectl get pods -n <namespace> -l app=<app-label> --no-headers | wc -l

# Calculate total connection pool size
# Total = (Number of Pods) × (Pool Size per Pod)
```

## Remediation

### Immediate Actions

#### Option 1: Kill Idle Connections

```bash
# Connect to database
kubectl exec -it <postgres-pod-name> -n <namespace> -- psql -U <username> -d <database>

# Inside psql - kill idle connections (CAREFUL!)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < now() - interval '5 minutes'
  AND pid != pg_backend_pid();

# Kill specific connection by PID (if identified as problematic)
SELECT pg_terminate_backend(<pid>);
```

#### Option 2: Restart Application Pods

```bash
# Restart deployment (rolling restart)
kubectl rollout restart deployment/<app-deployment> -n <namespace>

# Or delete specific pods (will be recreated)
kubectl delete pod <pod-name> -n <namespace>

# Watch restart progress
kubectl rollout status deployment/<app-deployment> -n <namespace>
```

#### Option 3: Scale Down Application (Temporary)

```bash
# Reduce number of application replicas temporarily
kubectl scale deployment/<app-deployment> -n <namespace> --replicas=2

# Verify scaling
kubectl get pods -n <namespace> -l app=<app-label>

# Wait for connections to drop
# Then scale back up with fixed pool settings
```

#### Option 4: Increase Database Max Connections (If Appropriate)

```bash
# Edit PostgreSQL ConfigMap (if using one)
kubectl edit configmap <postgres-config> -n <namespace>

# Add or update:
# max_connections = '200'

# Restart PostgreSQL (CAREFUL - causes downtime)
kubectl rollout restart statefulset/<postgres-statefulset> -n <namespace>

# Or for a pod
kubectl delete pod <postgres-pod-name> -n <namespace>
```

### Post-Incident Actions

1. **Audit Connection Pool Configuration**
   - Calculate appropriate pool size per pod
   - Formula: `max_connections / (num_pods * pool_size) > 1.2` (20% buffer)
   - Update application configuration

2. **Fix Connection Leaks**
   - Review application code for unclosed connections
   - Ensure proper try-finally or with-statement usage
   - Add connection pool monitoring to application

3. **Configure Connection Pool Settings**
   ```yaml
   # Example environment variables
   env:
   - name: DB_POOL_SIZE
     value: "10"
   - name: DB_POOL_TIMEOUT
     value: "30"
   - name: DB_POOL_RECYCLE
     value: "3600"
   - name: DB_MAX_OVERFLOW
     value: "5"
   ```

4. **Set Up Proper Monitoring**
   - Monitor active connections per application
   - Alert when connections > 80% of max
   - Track connection pool metrics from application

## Prevention

### 1. Calculate Proper Connection Pool Size

```
Formula:
max_connections (PostgreSQL) = (num_pods × pool_size) + buffer

Example:
- PostgreSQL max_connections = 100
- Number of app pods = 5
- Buffer = 20 connections
- Pool size per pod = (100 - 20) / 5 = 16

Set pool_size = 10-15 to leave headroom
```

### 2. Configure PostgreSQL Connection Limits

```sql
-- In postgresql.conf or ConfigMap
max_connections = 100
shared_buffers = 256MB  # Should be ~25% of RAM
```

### 3. Implement Connection Pooling Best Practices

```python
# Example: Python SQLAlchemy
engine = create_engine(
    DATABASE_URL,
    pool_size=10,              # Base pool size
    max_overflow=5,            # Additional connections if needed
    pool_timeout=30,           # Wait time before timeout
    pool_recycle=3600,         # Recycle connections after 1 hour
    pool_pre_ping=True         # Verify connection before use
)
```

### 4. Set Connection Timeouts

```sql
-- PostgreSQL settings
statement_timeout = 30000        # 30 seconds
idle_in_transaction_session_timeout = 60000  # 1 minute
```

### 5. Configure PgBouncer (Connection Pooler)

```ini
# pgbouncer.ini
[databases]
mydb = host=postgres port=5432 dbname=mydb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
```

### 6. Monitoring and Alerting

Set up alerts for:
- Active connections > 70% of max (warning)
- Active connections > 85% of max (critical)
- Connection pool wait time > 1s
- Connection errors in application metrics

### 7. Regular Audits

- Weekly: Review connection patterns and peak usage
- Monthly: Analyze slow queries and optimize
- Quarterly: Review and adjust pool sizes based on growth

## Related Alerts

- `DatabaseConnectionPoolExhausted` - Connections at max capacity
- `DatabaseConnectionsHigh` - Connections > 80% of max
- `DatabaseSlowQueries` - Queries taking too long
- `ApplicationDatabaseErrors` - DB-related application errors

## References

- [PostgreSQL Connection Pooling](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [PgBouncer Documentation](https://www.pgbouncer.org/config.html)
- [SQLAlchemy Engine Configuration](https://docs.sqlalchemy.org/en/latest/core/engines.html)
- [Database Performance Best Practices](../docs/architecture.md)
