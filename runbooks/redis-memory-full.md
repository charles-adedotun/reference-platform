# Redis Memory Full Runbook

## Overview
- **Alert**: RedisMemoryFull / RedisMemoryHigh / RedisEvictionRateHigh
- **Severity**: Critical / Warning
- **Service Impact**: Cache misses, performance degradation, potential data loss

## Symptoms

- Alert firing: `RedisMemoryFull`, `RedisMemoryHigh`, or `RedisEvictionRateHigh`
- Increased cache miss rate
- Application performance degradation
- Redis evicting keys unexpectedly
- OOM (Out of Memory) errors in Redis logs

## Investigation

### 1. Check Redis Memory Usage

```bash
# Connect to Redis pod
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli

# Inside redis-cli - check memory stats
INFO memory

# Key metrics to check:
# - used_memory_human: Current memory usage
# - used_memory_peak_human: Peak memory usage
# - maxmemory_human: Configured max memory
# - maxmemory_policy: Eviction policy
# - mem_fragmentation_ratio: Fragmentation (should be ~1.0-1.5)
```

### 2. Check Memory Configuration

```bash
# Inside redis-cli - check configuration
CONFIG GET maxmemory
CONFIG GET maxmemory-policy
CONFIG GET maxmemory-samples

# Check eviction stats
INFO stats | grep evicted
```

### 3. Analyze Key Distribution

```bash
# Inside redis-cli - get database size
DBSIZE

# Sample keys to understand types
RANDOMKEY
TYPE <key-from-above>

# Check key patterns (CAREFUL - can be expensive)
# Use with caution in production
SCAN 0 COUNT 100

# Get memory usage of specific key
MEMORY USAGE <key>

# Exit redis-cli
exit
```

### 4. Analyze Key Space by Pattern

```bash
# Using redis-cli with pattern scanning
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli --bigkeys

# This shows largest keys by type
# Look for unexpectedly large keys
```

### 5. Check for Memory Leaks or Growth

```bash
# Get Redis logs
kubectl logs <redis-pod-name> -n <namespace> --tail=200

# Check for OOM errors
kubectl logs <redis-pod-name> -n <namespace> | grep -i "oom\|memory\|evict"

# Check Redis pod resource usage
kubectl top pod <redis-pod-name> -n <namespace>
```

### 6. Check Application Cache Usage

```bash
# Check application logs for cache-related errors
kubectl logs -n <namespace> -l app=<app-label> --tail=200 | grep -i "cache\|redis"

# Look for patterns of excessive caching
# Check for cache key patterns and TTLs
```

## Remediation

### Immediate Actions

#### Option 1: Flush Unused or Old Data

```bash
# Connect to Redis
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli

# Inside redis-cli - flush specific database (CAREFUL!)
SELECT <db-number>
FLUSHDB

# Or flush all databases (VERY CAREFUL!)
# FLUSHALL

# Or delete specific key patterns (safer)
# Using redis-cli --scan and --pattern
exit

# From shell - delete keys by pattern
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli --scan --pattern "temp:*" | xargs kubectl exec -i <redis-pod-name> -n <namespace> -- redis-cli DEL
```

#### Option 2: Increase Memory Limit

```bash
# Connect to Redis
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli

# Inside redis-cli - increase max memory (temporary)
CONFIG SET maxmemory 2gb

# Verify change
CONFIG GET maxmemory

# Exit
exit

# Make permanent by updating deployment
kubectl edit statefulset <redis-statefulset> -n <namespace>
# Or update ConfigMap if using one
```

#### Option 3: Configure Eviction Policy

```bash
# Connect to Redis
kubectl exec -it <redis-pod-name> -n <namespace> -- redis-cli

# Inside redis-cli - set eviction policy
# Options: noeviction, allkeys-lru, volatile-lru, allkeys-random, volatile-random, volatile-ttl

# Set LRU eviction on all keys
CONFIG SET maxmemory-policy allkeys-lru

# Or LRU only on keys with TTL
CONFIG SET maxmemory-policy volatile-lru

# Verify
CONFIG GET maxmemory-policy

exit
```

#### Option 4: Restart Redis (Last Resort)

```bash
# This will clear all data - ensure you have persistence or can rebuild cache

# Delete pod (will restart if part of StatefulSet/Deployment)
kubectl delete pod <redis-pod-name> -n <namespace>

# Or rolling restart
kubectl rollout restart statefulset/<redis-statefulset> -n <namespace>

# Monitor restart
kubectl get pods -n <namespace> -w
```

### Post-Incident Actions

1. **Analyze Key Patterns**
   - Identify which keys are consuming most memory
   - Review application caching strategy
   - Implement better TTL policies

2. **Optimize Key Storage**
   - Use hash data structures for related data
   - Compress large values before storing
   - Set appropriate TTLs on all keys

3. **Update Redis Configuration**
   ```yaml
   # Example ConfigMap for Redis
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: redis-config
   data:
     redis.conf: |
       maxmemory 2gb
       maxmemory-policy allkeys-lru
       maxmemory-samples 5
       # Enable persistence
       save 900 1
       save 300 10
       save 60 10000
   ```

4. **Configure Resource Limits**
   ```yaml
   resources:
     requests:
       memory: "2Gi"
       cpu: "500m"
     limits:
       memory: "3Gi"
       cpu: "2000m"
   ```

## Prevention

### 1. Set Appropriate Memory Limits

```yaml
# StatefulSet configuration
spec:
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        resources:
          requests:
            memory: "2Gi"
          limits:
            memory: "3Gi"
        command:
        - redis-server
        - --maxmemory 2gb
        - --maxmemory-policy allkeys-lru
```

### 2. Implement Proper TTL Strategies

```python
# Application code example - always set TTL
import redis

r = redis.Redis()

# Set with TTL (in seconds)
r.setex("session:123", 3600, "session_data")  # 1 hour

# Or using EXPIRE
r.set("user:456", "user_data")
r.expire("user:456", 86400)  # 24 hours

# Use SETEX for atomic set+expire
r.setex("cache:query:789", 300, "query_result")  # 5 minutes
```

### 3. Configure Eviction Policy

Choose the right policy for your use case:

- **allkeys-lru**: Good for general caching (recommended)
- **volatile-lru**: Only evict keys with TTL
- **allkeys-lfu**: Evict least frequently used
- **volatile-ttl**: Evict keys with shortest TTL
- **noeviction**: Return errors when memory full (use with caution)

```conf
maxmemory-policy allkeys-lru
maxmemory-samples 5  # Higher = more accurate LRU, but slower
```

### 4. Enable Redis Persistence (If Needed)

```conf
# RDB snapshots
save 900 1      # Save if 1 key changed in 15 min
save 300 10     # Save if 10 keys changed in 5 min
save 60 10000   # Save if 10000 keys changed in 1 min

# AOF (Append-Only File) - more durable
appendonly yes
appendfsync everysec
```

### 5. Use Redis Data Structures Efficiently

```python
# Use hashes for structured data (more memory efficient)
# Instead of:
r.set("user:123:name", "John")
r.set("user:123:email", "john@example.com")
r.set("user:123:age", "30")

# Use:
r.hset("user:123", mapping={
    "name": "John",
    "email": "john@example.com",
    "age": "30"
})

# Compress large values
import zlib
import json

data = {"large": "data" * 1000}
compressed = zlib.compress(json.dumps(data).encode())
r.set("compressed:key", compressed)
```

### 6. Implement Cache Warming

```python
# Prevent cache stampede after flush/restart
# Pre-populate critical cache entries
def warm_cache():
    critical_keys = get_critical_cache_keys()
    for key in critical_keys:
        if not r.exists(key):
            data = fetch_from_db(key)
            r.setex(key, 3600, data)
```

### 7. Monitor Memory Usage

Set up monitoring for:
- Memory usage (alert at 70%, 85%)
- Eviction rate (alert if > 100/sec)
- Memory fragmentation ratio (alert if > 1.5)
- Cache hit rate (alert if < 80%)
- Key count growth

```yaml
# Example Prometheus alerts
- alert: RedisMemoryHigh
  expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.85
  for: 5m
  labels:
    severity: warning

- alert: RedisEvictionRateHigh
  expr: rate(redis_evicted_keys_total[5m]) > 100
  for: 5m
  labels:
    severity: warning
```

### 8. Regular Maintenance

- **Weekly**: Review key distribution and memory usage
- **Monthly**: Analyze cache hit/miss ratios and optimize
- **Quarterly**: Review and adjust memory limits based on usage patterns

### 9. Implement Circuit Breakers

```python
# Prevent overwhelming Redis during issues
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60)
def get_from_cache(key):
    return redis_client.get(key)

# Fallback to database if Redis fails
def get_data(key):
    try:
        cached = get_from_cache(key)
        if cached:
            return cached
    except:
        logger.warning("Redis unavailable, using database")

    return get_from_database(key)
```

## Related Alerts

- `RedisMemoryHigh` - Memory usage > 80%
- `RedisMemoryFull` - Memory at max capacity
- `RedisEvictionRateHigh` - High key eviction rate
- `RedisCacheMissRateHigh` - Cache effectiveness degraded
- `RedisMemoryFragmentationHigh` - Memory fragmentation issues

## References

- [Redis Memory Optimization](https://redis.io/docs/management/optimization/memory-optimization/)
- [Redis Eviction Policies](https://redis.io/docs/reference/eviction/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)
- [Redis Best Practices](https://redis.io/docs/management/optimization/)
- [Observability Documentation](../docs/observability.md)
