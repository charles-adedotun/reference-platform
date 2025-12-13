# Runbooks

This directory contains operational runbooks for common incident scenarios.

## Alert-to-Runbook Mapping

| Alert Name | Severity | Runbook | Description |
|------------|----------|---------|-------------|
| `HighCPUUsage` | warning | [high-cpu-usage.md](./high-cpu-usage.md) | Pod CPU usage > 80% |
| `CriticalCPUUsage` | critical | [high-cpu-usage.md](./high-cpu-usage.md) | Pod CPU usage > 95% |
| `DatabaseConnectionPoolExhausted` | critical | [database-connection-exhausted.md](./database-connection-exhausted.md) | Postgres connection pool at capacity |
| `DatabaseConnectionsHigh` | warning | [database-connection-exhausted.md](./database-connection-exhausted.md) | Postgres connections > 80% of max |
| `RedisMemoryHigh` | warning | [redis-memory-full.md](./redis-memory-full.md) | Redis memory usage > 80% |
| `RedisMemoryFull` | critical | [redis-memory-full.md](./redis-memory-full.md) | Redis memory at max capacity |
| `RedisEvictionRateHigh` | warning | [redis-memory-full.md](./redis-memory-full.md) | Redis evicting keys due to memory |
| `PodCrashLooping` | critical | [pod-crashloop.md](./pod-crashloop.md) | Pod in CrashLoopBackOff state |
| `PodRestartRateHigh` | warning | [pod-crashloop.md](./pod-crashloop.md) | Pod restart count increasing |

## Runbook Format

Each runbook follows a standard structure:

1. **Symptoms** - How to identify the issue
2. **Investigation** - Step-by-step diagnostic commands
3. **Remediation** - Actions to resolve the issue
4. **Prevention** - Long-term fixes and improvements
5. **Related Alerts** - Associated monitoring alerts
6. **References** - Additional documentation

## Using Runbooks

1. Identify the alert from your monitoring system
2. Find the corresponding runbook in the table above
3. Follow the investigation steps to diagnose the issue
4. Apply remediation as needed
5. Document the incident in a postmortem if appropriate

## Contributing

When adding new runbooks:
- Follow the standard format
- Include real kubectl/psql/redis-cli commands
- Test all commands in a safe environment
- Update this README with the alert mapping
