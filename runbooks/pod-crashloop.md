# Pod CrashLoopBackOff Runbook

## Overview
- **Alert**: PodCrashLooping / PodRestartRateHigh
- **Severity**: Critical / Warning
- **Service Impact**: Service degradation or complete failure, reduced capacity

## Symptoms

- Alert firing: `PodCrashLooping` or `PodRestartRateHigh`
- Pods showing `CrashLoopBackOff` status
- Application unavailable or degraded
- Increased error rates in monitoring
- Service endpoints returning errors

## Investigation

### 1. Identify Crashing Pods

```bash
# List pods with issues
kubectl get pods -n <namespace>

# Find pods in CrashLoopBackOff
kubectl get pods -n <namespace> | grep CrashLoopBackOff

# Get detailed pod status
kubectl describe pod <pod-name> -n <namespace>

# Check restart count
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' | sort -k2 -nr
```

### 2. Check Pod Logs

```bash
# Get current logs
kubectl logs <pod-name> -n <namespace>

# Get logs from previous crashed container
kubectl logs <pod-name> -n <namespace> --previous

# For multi-container pods, specify container
kubectl logs <pod-name> -n <namespace> -c <container-name> --previous

# Stream logs (if pod stays up long enough)
kubectl logs -f <pod-name> -n <namespace>

# Get last 100 lines
kubectl logs <pod-name> -n <namespace> --tail=100 --previous
```

### 3. Check Pod Events

```bash
# Get events for specific pod
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 Events:

# Get all recent events in namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -30

# Filter for pod-specific events
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>
```

### 4. Check Container Exit Code

```bash
# Get exit code and reason
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'

# Common exit codes:
# 0: Successful exit (shouldn't cause crash loop)
# 1: Application error
# 137: SIGKILL (OOMKilled - out of memory)
# 139: SIGSEGV (segmentation fault)
# 143: SIGTERM (graceful termination)
```

### 5. Check Resource Constraints

```bash
# Check if OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep -i "oom\|memory"

# Check resource usage
kubectl top pod <pod-name> -n <namespace>

# Get resource limits
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Check node resources
kubectl top nodes
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

### 6. Check ConfigMaps and Secrets

```bash
# List ConfigMaps
kubectl get configmaps -n <namespace>

# Check ConfigMap content
kubectl get configmap <configmap-name> -n <namespace> -o yaml

# Check if mounted correctly
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Mounts:

# Verify secrets exist
kubectl get secrets -n <namespace>
```

### 7. Check Health Probes

```bash
# Get probe configuration
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 "livenessProbe:\|readinessProbe:\|startupProbe:"

# Check probe failures in events
kubectl describe pod <pod-name> -n <namespace> | grep -i "liveness\|readiness\|probe"
```

### 8. Check Recent Changes

```bash
# Check deployment history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Compare with previous revision
kubectl rollout history deployment/<deployment-name> -n <namespace> --revision=<n>

# Check when pod was created
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.creationTimestamp}'

# Check image version
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].image}'
```

## Remediation

### Common Causes and Solutions

#### Cause 1: Out of Memory (Exit Code 137)

```bash
# Confirm OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep -i oom

# Solution: Increase memory limits
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"1Gi"},"requests":{"memory":"512Mi"}}}]}}}}'

# Or edit deployment
kubectl edit deployment <deployment-name> -n <namespace>
```

#### Cause 2: Application Configuration Error

```bash
# Check logs for config errors
kubectl logs <pod-name> -n <namespace> --previous | grep -i "error\|fail\|config"

# Solution: Fix ConfigMap
kubectl edit configmap <configmap-name> -n <namespace>

# Restart deployment to pick up changes
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

#### Cause 3: Missing Dependencies (Database, Redis, etc.)

```bash
# Check if dependencies are running
kubectl get pods -n <namespace>

# Check connectivity from pod
kubectl exec -it <pod-name> -n <namespace> -- wget -O- <service-name>:8080/health
kubectl exec -it <pod-name> -n <namespace> -- nc -zv <postgres-service> 5432

# Solution: Start dependencies or fix network policies
kubectl rollout restart deployment/<dependency-deployment> -n <namespace>
```

#### Cause 4: Liveness Probe Too Aggressive

```bash
# Check probe configuration
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 livenessProbe

# Solution: Adjust probe timings
kubectl edit deployment <deployment-name> -n <namespace>

# Increase initialDelaySeconds, periodSeconds, or failureThreshold
```

Example probe configuration:
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30  # Increase if app needs more startup time
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3      # Increase for more tolerance
  successThreshold: 1
```

#### Cause 5: Bad Image or Recent Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Or rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<revision>

# Check rollback status
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

#### Cause 6: Secrets or ConfigMaps Not Found

```bash
# Check what's mounted
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 "Volumes:\|Mounts:"

# Verify secret exists
kubectl get secret <secret-name> -n <namespace>

# Solution: Create missing secret
kubectl create secret generic <secret-name> -n <namespace> --from-literal=key=value

# Or fix reference in deployment
kubectl edit deployment <deployment-name> -n <namespace>
```

#### Cause 7: Storage Issues

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Describe PVC for errors
kubectl describe pvc <pvc-name> -n <namespace>

# Check if volume is mounted
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Volumes:"

# Solution: Fix PVC or create if missing
kubectl apply -f pvc.yaml
```

### General Remediation Steps

#### Option 1: Delete Pod (Force Restart)

```bash
# Delete single pod (will be recreated by deployment)
kubectl delete pod <pod-name> -n <namespace>

# Force delete if stuck
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

#### Option 2: Restart Deployment

```bash
# Rolling restart
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Watch progress
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

#### Option 3: Scale Down and Up

```bash
# Scale to 0
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=0

# Wait a moment, then scale back up
kubectl scale deployment/<deployment-name> -n <namespace> --replicas=3
```

#### Option 4: Debug with Ephemeral Container

```bash
# Add debug container to running pod (K8s 1.23+)
kubectl debug <pod-name> -n <namespace> -it --image=busybox --target=<container-name>

# Or create debug pod with same spec
kubectl debug <pod-name> -n <namespace> -it --copy-to=debug-pod --container=debug
```

## Prevention

### 1. Implement Proper Health Checks

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        # Startup probe - for slow-starting applications
        startupProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 30  # Allow 5 minutes to start

        # Liveness probe - restart if unhealthy
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness probe - remove from service if not ready
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
```

### 2. Set Appropriate Resource Limits

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

### 3. Implement Graceful Shutdown

```yaml
# Application code should handle SIGTERM
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]

# Give enough time to shut down
terminationGracePeriodSeconds: 30
```

### 4. Use Init Containers for Dependencies

```yaml
initContainers:
- name: wait-for-db
  image: busybox:1.35
  command:
  - sh
  - -c
  - |
    until nc -zv postgres 5432; do
      echo "Waiting for postgres..."
      sleep 2
    done
```

### 5. Validate Configuration Before Deployment

```bash
# Dry-run before applying
kubectl apply -f deployment.yaml --dry-run=client

# Validate YAML
kubectl apply -f deployment.yaml --validate=true --dry-run=server

# Use admission controllers (OPA, Kyverno) to enforce policies
```

### 6. Implement Circuit Breakers and Retries

```python
# Application code - handle transient failures
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=2, max=30)
)
def connect_to_database():
    # Connection logic with retry
    pass
```

### 7. Use Pod Disruption Budgets

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

### 8. Monitor and Alert

Set up alerts for:
- Pod restart count > 5 in 10 minutes
- CrashLoopBackOff state
- OOMKilled events
- Failed health probe counts

### 9. Regular Testing

- Test application startup with realistic delays
- Test with resource constraints
- Perform chaos engineering (kill pods randomly)
- Regular game days to practice incident response

## Related Alerts

- `PodCrashLooping` - Pod in CrashLoopBackOff
- `PodRestartRateHigh` - High restart frequency
- `PodOOMKilled` - Pod killed due to OOM
- `PodFailedScheduling` - Pod cannot be scheduled
- `LivenessProbeFailure` - Liveness probe failing

## References

- [Kubernetes Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [Deployment Documentation](../docs/deployment.md)
