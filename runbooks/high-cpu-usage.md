# High CPU Usage Runbook

## Overview
- **Alert**: HighCPUUsage / CriticalCPUUsage
- **Severity**: Warning (>80%) / Critical (>95%)
- **Service Impact**: Performance degradation, potential service timeouts

## Symptoms

- Alert firing: `HighCPUUsage` or `CriticalCPUUsage`
- Application response times increasing
- Request timeouts or 5xx errors
- Pod throttling visible in metrics

## Investigation

### 1. Identify Affected Pods

```bash
# List pods by CPU usage
kubectl top pods -n <namespace> --sort-by=cpu

# Get detailed pod metrics
kubectl describe pod <pod-name> -n <namespace>

# Check if pod is being throttled
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].state}'
```

### 2. Check CPU Limits and Requests

```bash
# View resource configuration
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Check current vs requested resources
kubectl top pod <pod-name> -n <namespace> --containers
```

### 3. Analyze Application Logs

```bash
# View recent logs
kubectl logs <pod-name> -n <namespace> --tail=100

# Check for error patterns
kubectl logs <pod-name> -n <namespace> --tail=500 | grep -i "error\|exception\|timeout"

# Follow logs in real-time
kubectl logs -f <pod-name> -n <namespace>
```

### 4. Check for Resource-Intensive Operations

```bash
# Exec into pod and check processes (if debugging tools available)
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Inside pod (if tools available):
top
ps aux --sort=-%cpu | head -10
```

### 5. Review Recent Changes

```bash
# Check deployment history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# View recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check recent pod restarts
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}'
```

### 6. Check Horizontal Pod Autoscaler

```bash
# Check HPA status
kubectl get hpa -n <namespace>

# Describe HPA for details
kubectl describe hpa <hpa-name> -n <namespace>

# Check if scaling is occurring
kubectl get hpa <hpa-name> -n <namespace> -w
```

## Remediation

### Immediate Actions

#### Option 1: Scale Up (Quick Fix)

```bash
# Manually increase replicas
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=<new-count>

# Verify scaling
kubectl get pods -n <namespace> -w
```

#### Option 2: Increase CPU Limits (If Throttled)

```bash
# Edit deployment to increase CPU limits
kubectl edit deployment/<deployment-name> -n <namespace>

# Or patch with specific values
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"cpu":"2000m"},"requests":{"cpu":"500m"}}}]}}}}'

# Watch rollout
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

#### Option 3: Restart Deployment (If Application Leak)

```bash
# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Monitor restart
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

#### Option 4: Rollback (If Recent Deploy Caused Issue)

```bash
# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Or rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<revision>

# Verify rollback
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

### Post-Incident Actions

1. **Analyze Application Performance**
   - Review application profiling data
   - Check for inefficient queries or algorithms
   - Look for memory leaks causing GC pressure

2. **Adjust Resource Requests/Limits**
   - Update deployment manifests with appropriate CPU values
   - Ensure requests match actual usage patterns
   - Set limits to prevent resource exhaustion

3. **Configure Autoscaling**
   ```bash
   # Create HPA if not exists
   kubectl autoscale deployment <deployment-name> -n <namespace> \
     --cpu-percent=70 \
     --min=3 \
     --max=10
   ```

4. **Enable CPU Profiling**
   - Add profiling endpoints to application
   - Configure continuous profiling (if available)
   - Collect profiles during high CPU periods

## Prevention

### 1. Set Appropriate Resource Limits

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
```

### 2. Implement Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 3. Configure Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### 4. Performance Optimization
- Profile application code regularly
- Optimize database queries
- Implement caching strategies
- Use async/non-blocking operations
- Review and optimize algorithms

### 5. Monitoring and Alerting
- Set up CPU usage alerts at 70% (warning) and 85% (critical)
- Monitor CPU throttling metrics
- Track request latency correlated with CPU usage
- Set up SLO alerts for user-facing metrics

## Related Alerts

- `HighCPUUsage` - CPU usage > 80%
- `CriticalCPUUsage` - CPU usage > 95%
- `PodThrottling` - Container being CPU throttled
- `HighRequestLatency` - Often correlated with CPU issues

## References

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [CPU Throttling in Kubernetes](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run)
- [Observability Documentation](../docs/observability.md)
