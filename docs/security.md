# Security Guide

Comprehensive security practices and policy enforcement for the reference platform.

## Table of Contents

- [Security Overview](#security-overview)
- [Container Security](#container-security)
- [Network Security](#network-security)
- [Authentication and Authorization](#authentication-and-authorization)
- [Secrets Management](#secrets-management)
- [Pod Security](#pod-security)
- [Image Security](#image-security)
- [Policy Enforcement](#policy-enforcement)
- [Vulnerability Management](#vulnerability-management)
- [Audit Logging](#audit-logging)
- [Compliance](#compliance)

---

## Security Overview

### Defense in Depth

The reference platform implements multiple layers of security controls:

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Network Security                               │
│ - Network Policies, Firewalls, Private Networks         │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Identity & Access                              │
│ - RBAC, Service Accounts, OAuth2/OIDC                   │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Pod Security                                   │
│ - Security Context, PSS/PSA, AppArmor, Seccomp          │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Container Security                             │
│ - Image Scanning, SBOM, Signatures, Distroless          │
├─────────────────────────────────────────────────────────┤
│ Layer 5: Application Security                           │
│ - Input Validation, Encryption, Secure Coding           │
├─────────────────────────────────────────────────────────┤
│ Layer 6: Data Security                                  │
│ - Encryption at Rest, TLS, Backup Encryption            │
└─────────────────────────────────────────────────────────┘
```

### Security Principles

1. **Least Privilege**: Grant minimum permissions required
2. **Zero Trust**: Verify all access, never assume trust
3. **Defense in Depth**: Multiple layers of security controls
4. **Fail Secure**: Default to denying access on failure
5. **Security by Default**: Secure configurations out of the box
6. **Immutability**: Immutable infrastructure and containers

---

## Container Security

### Secure Base Images

Use minimal, trusted base images:

```dockerfile
# GOOD: Distroless base image
FROM gcr.io/distroless/static-debian11

# GOOD: Alpine for smaller attack surface
FROM alpine:3.18

# AVOID: Large base images with unnecessary packages
# FROM ubuntu:latest
```

### Multi-Stage Builds

```dockerfile
# Build stage
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o myapp

# Runtime stage - minimal image
FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/myapp /myapp
USER nonroot:nonroot
ENTRYPOINT ["/myapp"]
```

### Non-Root Containers

```dockerfile
# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Switch to non-root user
USER appuser

# Kubernetes will enforce this
```

### Read-Only Root Filesystem

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: myapp
    image: myapp:latest
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

---

## Network Security

### Network Policies

```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow specific ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080

---
# Allow egress to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-db-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:  # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### TLS/mTLS

```yaml
# Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

### Service Mesh (Optional)

```yaml
# Istio: Enforce mTLS between services
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

---

## Authentication and Authorization

### Kubernetes RBAC

```yaml
# ServiceAccount for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
  namespace: production

---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["api-config"]  # Restrict to specific resource
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["api-secrets"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-rolebinding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: api-role
subjects:
- kind: ServiceAccount
  name: api-sa
  namespace: production

---
# Deployment using ServiceAccount
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  template:
    spec:
      serviceAccountName: api-sa
      automountServiceAccountToken: false  # Disable if not needed
```

### Application-Level Authentication

```yaml
# OAuth2 Proxy for authentication
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
spec:
  template:
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:latest
        args:
        - --provider=github
        - --email-domain=*
        - --upstream=http://api:8080
        - --http-address=0.0.0.0:4180
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy
              key: client-id
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy
              key: client-secret
```

---

## Secrets Management

### Kubernetes Secrets

```bash
# Create secret from literal
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password='SecureP@ssw0rd!' \
  -n production

# Create secret from file
kubectl create secret generic tls-cert \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem \
  -n production

# Create secret from env file
kubectl create secret generic app-env \
  --from-env-file=.env \
  -n production
```

### Using Secrets in Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: myapp:latest
    env:
    # From secret
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    # From ConfigMap
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
    volumeMounts:
    # Mount secret as file
    - name: tls-cert
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls-cert
    secret:
      secretName: tls-cert
```

### External Secrets Management

```yaml
# Using External Secrets Operator with AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: production
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

### Sealed Secrets

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubectl create secret generic mysecret \
  --from-literal=password=secret \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml

# Commit sealed secret to Git (safe!)
git add mysealedsecret.yaml
git commit -m "Add sealed secret"
```

---

## Pod Security

### Pod Security Standards

```yaml
# Enforce Pod Security Standards at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: myapp
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    resources:
      limits:
        memory: "512Mi"
        cpu: "1000m"
      requests:
        memory: "256Mi"
        cpu: "500m"
```

### AppArmor Profile

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  annotations:
    container.apparmor.security.beta.kubernetes.io/myapp: runtime/default
spec:
  containers:
  - name: myapp
    image: myapp:latest
```

### Seccomp Profile

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault  # Or Localhost for custom profiles
  containers:
  - name: myapp
    image: myapp:latest
```

---

## Image Security

### Image Scanning

```bash
# Scan with Trivy
./scripts/run-trivy.sh myapp:v1.2.3 image CRITICAL

# Scan in CI/CD
trivy image --severity HIGH,CRITICAL \
  --exit-code 1 \
  --no-progress \
  myapp:v1.2.3
```

### Image Signing with Cosign

```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myapp:v1.2.3

# Verify signature
cosign verify --key cosign.pub myapp:v1.2.3
```

### Image Policy Enforcement

```yaml
# Using Kyverno to verify image signatures
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              ...
              -----END PUBLIC KEY-----
```

### Allowed Registries

```yaml
# Kyverno: Only allow images from trusted registries
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must be from approved registries"
      pattern:
        spec:
          containers:
          - image: "registry.example.com/* | gcr.io/distroless/*"
```

---

## Policy Enforcement

### OPA Gatekeeper

```yaml
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

---
# Constraint Template: Require labels
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels

      violation[{"msg": msg, "details": {"missing_labels": missing}}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Missing required labels: %v", [missing])
      }

---
# Constraint: Enforce labels
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-labels
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces:
    - production
  parameters:
    labels:
    - app
    - owner
    - environment
```

### Kyverno Policies

```yaml
# Require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-resources
    match:
      any:
      - resources:
          kinds:
          - Deployment
    validate:
      message: "Resource limits are required"
      pattern:
        spec:
          template:
            spec:
              containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
                  requests:
                    memory: "?*"
                    cpu: "?*"

---
# Add security context
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-security-context
spec:
  rules:
  - name: add-runAsNonRoot
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
```

---

## Vulnerability Management

### Continuous Scanning

```yaml
# Scan images in running cluster
apiVersion: batch/v1
kind: CronJob
metadata:
  name: image-scanner
  namespace: security
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scanner-sa
          containers:
          - name: trivy-scanner
            image: aquasec/trivy:latest
            command:
            - sh
            - -c
            - |
              # Scan all images in cluster
              kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | \
              sort -u | \
              while read image; do
                echo "Scanning $image"
                trivy image --severity HIGH,CRITICAL "$image"
              done
          restartPolicy: OnFailure
```

### Vulnerability Remediation

```
1. Scan identifies CVE-2023-12345 in base image

2. Check if fix available
   - New base image version?
   - Security patch?

3. Update Dockerfile
   FROM alpine:3.17 → FROM alpine:3.18

4. Rebuild and test
   docker build -t myapp:v1.2.4 .
   docker run --rm myapp:v1.2.4 ./run-tests.sh

5. Rescan
   trivy image myapp:v1.2.4

6. Deploy to staging
   Update image tag in gitops/staging/

7. Verify in staging

8. Deploy to production
   Update image tag in gitops/production/
```

---

## Audit Logging

### Enable Kubernetes Audit Logs

```yaml
# Audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log secrets changes at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]

# Log pod changes at Request level
- level: Request
  resources:
  - group: ""
    resources: ["pods"]
  verbs: ["create", "delete"]

# Log all authentication requests
- level: Request
  users: ["system:anonymous"]
  verbs: ["*"]

# Don't log read requests on non-sensitive resources
- level: None
  resources:
  - group: ""
    resources: ["events", "nodes/status"]
  verbs: ["get", "list", "watch"]
```

### Application Audit Logging

```python
import logging

audit_logger = logging.getLogger('audit')

def audit_log(user, action, resource, status):
    audit_logger.info({
        'timestamp': datetime.utcnow().isoformat(),
        'user': user,
        'action': action,
        'resource': resource,
        'status': status,
        'ip_address': request.remote_addr
    })

@app.route('/api/users/<user_id>', methods=['DELETE'])
def delete_user(user_id):
    audit_log(
        user=current_user.id,
        action='DELETE',
        resource=f'user:{user_id}',
        status='SUCCESS'
    )
```

---

## Compliance

### CIS Kubernetes Benchmark

```bash
# Run kube-bench to check CIS compliance
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# View results
kubectl logs -n kube-bench -l app=kube-bench

# Address findings in priority order
```

### Security Scanning Checklist

- [ ] Container images scanned for vulnerabilities
- [ ] SBOM generated for all images
- [ ] Images signed with Cosign
- [ ] Network policies enforced
- [ ] Pod Security Standards enforced
- [ ] RBAC configured with least privilege
- [ ] Secrets encrypted at rest
- [ ] TLS enabled for all external traffic
- [ ] Audit logging enabled
- [ ] Regular security assessments
- [ ] Incident response plan documented

---

## Security Automation

### Pre-Commit Hooks

```bash
# .pre-commit-config.yaml
repos:
- repo: https://github.com/Yelp/detect-secrets
  rev: v1.4.0
  hooks:
  - id: detect-secrets
    args: ['--baseline', '.secrets.baseline']

- repo: local
  hooks:
  - id: trivy-scan
    name: Trivy vulnerability scanner
    entry: ./scripts/run-trivy.sh
    language: script
    pass_filenames: false
```

### CI/CD Security Gates

```yaml
# GitHub Actions example
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.IMAGE_NAME }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'

    - name: Upload Trivy results to GitHub Security
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Generate SBOM
      run: ./scripts/generate-sbom.sh ${{ env.IMAGE_NAME }}

    - name: Sign image
      run: |
        cosign sign --key ${{ secrets.COSIGN_KEY }} \
          ${{ env.IMAGE_NAME }}
```

---

## References

- [SLSA Provenance](./slsa-provenance.md)
- [Architecture Documentation](./architecture.md)
- [Deployment Guide](./deployment.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
