# SLSA Provenance and Supply Chain Security

Guide to implementing SLSA (Supply chain Levels for Software Artifacts) provenance and securing the software supply chain.

## Table of Contents

- [Overview](#overview)
- [SLSA Levels](#slsa-levels)
- [SBOM Generation](#sbom-generation)
- [Provenance Generation](#provenance-generation)
- [Image Signing and Verification](#image-signing-and-verification)
- [Attestations](#attestations)
- [Supply Chain Security](#supply-chain-security)
- [Verification Workflows](#verification-workflows)
- [Policy Enforcement](#policy-enforcement)

---

## Overview

SLSA (Supply chain Levels for Software Artifacts) is a security framework for ensuring the integrity of software artifacts throughout the software supply chain.

### Why SLSA?

- **Trust**: Verify software hasn't been tampered with
- **Transparency**: Know what's in your software
- **Traceability**: Track software back to source code
- **Security**: Prevent supply chain attacks

### Key Concepts

```
Source Code → Build → Package → Deploy
     ↓          ↓        ↓         ↓
  Commit    Provenance  SBOM   Signature
```

---

## SLSA Levels

### SLSA Level 0 (Baseline)

- No guarantees
- Manual processes
- Current state for many projects

### SLSA Level 1 (Current Target)

Requirements:
- [x] Build process is fully scripted/automated
- [x] Provenance generated
- [x] Provenance is available

```bash
# Generate provenance during build
slsa-github-generator \
  --subject=myapp:v1.2.3 \
  --predicate-type=https://slsa.dev/provenance/v0.2
```

### SLSA Level 2

Additional requirements:
- [ ] Version control for source
- [ ] Build service generates provenance
- [ ] Provenance is authenticated

### SLSA Level 3

Additional requirements:
- [ ] Isolated build environment
- [ ] Provenance includes build parameters
- [ ] Provenance is non-falsifiable

### SLSA Level 4 (Highest)

Additional requirements:
- [ ] Two-person review of changes
- [ ] Hermetic, reproducible builds
- [ ] All dependencies are tracked

---

## SBOM Generation

### Using Syft

```bash
# Generate SBOM for container image
./scripts/generate-sbom.sh myapp:v1.2.3

# Generates: sbom-myapp-v1.2.3.spdx.json

# SBOM includes:
# - All packages and dependencies
# - Versions and licenses
# - File hashes
# - Relationships between components
```

### SBOM Formats

#### SPDX (Recommended)

```bash
# Generate SPDX JSON
syft myapp:v1.2.3 -o spdx-json > sbom.spdx.json

# Validate SPDX
pyspdxtools -i sbom.spdx.json
```

#### CycloneDX

```bash
# Generate CycloneDX JSON
syft myapp:v1.2.3 -o cyclonedx-json > sbom.cdx.json
```

### SBOM Content Example

```json
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "myapp-v1.2.3",
  "documentNamespace": "https://example.com/sbom/myapp-v1.2.3",
  "packages": [
    {
      "SPDXID": "SPDXRef-Package-alpine",
      "name": "alpine",
      "versionInfo": "3.18.0",
      "downloadLocation": "https://hub.docker.com/_/alpine",
      "filesAnalyzed": false,
      "licenseConcluded": "MIT",
      "checksums": [
        {
          "algorithm": "SHA256",
          "checksumValue": "abc123..."
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-myapp",
      "name": "myapp",
      "versionInfo": "1.2.3",
      "supplier": "Organization: Example Corp",
      "filesAnalyzed": true,
      "licenseConcluded": "Apache-2.0"
    }
  ]
}
```

### Storing SBOMs

```bash
# Store SBOM alongside image in registry
crane append \
  --new-layer sbom.spdx.json \
  --image myapp:v1.2.3 \
  --output-image myapp:v1.2.3

# Or store in separate registry
crane cp sbom.spdx.json \
  registry.example.com/sboms/myapp:v1.2.3
```

---

## Provenance Generation

### What is Provenance?

Provenance is metadata about how an artifact was built:

- Source repository and commit
- Build platform and tools
- Build parameters
- Builder identity
- Timestamps

### Generating Provenance with GitHub Actions

```yaml
name: Build and Provenance

on:
  push:
    tags:
    - 'v*'

permissions:
  contents: read
  packages: write
  id-token: write  # For OIDC

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Build image
      run: |
        docker build -t myapp:${{ github.ref_name }} .

    - name: Generate provenance
      uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.9.0
      with:
        image: myapp
        tag: ${{ github.ref_name }}
        registry-username: ${{ github.actor }}
        registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Provenance Format (in-toto)

```json
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "subject": [
    {
      "name": "registry.example.com/myapp",
      "digest": {
        "sha256": "abc123..."
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "predicate": {
    "builder": {
      "id": "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.9.0"
    },
    "buildType": "https://github.com/slsa-framework/slsa-github-generator/container@v1",
    "invocation": {
      "configSource": {
        "uri": "git+https://github.com/example/myapp@refs/heads/main",
        "digest": {
          "sha1": "def456..."
        },
        "entryPoint": ".github/workflows/build.yml"
      }
    },
    "metadata": {
      "buildStartedOn": "2024-01-15T10:00:00Z",
      "buildFinishedOn": "2024-01-15T10:15:00Z"
    },
    "materials": [
      {
        "uri": "git+https://github.com/example/myapp",
        "digest": {
          "sha1": "def456..."
        }
      }
    ]
  }
}
```

---

## Image Signing and Verification

### Signing with Cosign

```bash
# Generate key pair (one-time)
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secure!)
# - cosign.pub (public key - distribute)

# Sign container image
cosign sign --key cosign.key myapp:v1.2.3

# Sign with OIDC (keyless signing)
cosign sign myapp:v1.2.3

# Verify signature
cosign verify --key cosign.pub myapp:v1.2.3
```

### Keyless Signing with OIDC

```bash
# Sign using GitHub OIDC (no key management!)
# Requires: GITHUB_TOKEN, COSIGN_EXPERIMENTAL=1

export COSIGN_EXPERIMENTAL=1

cosign sign \
  --oidc-issuer=https://token.actions.githubusercontent.com \
  myapp:v1.2.3

# Verify keyless signature
cosign verify \
  --certificate-identity=https://github.com/example/myapp/.github/workflows/build.yml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  myapp:v1.2.3
```

### Storing Signatures

Signatures are stored in the registry alongside the image:

```
registry.example.com/myapp:v1.2.3
registry.example.com/myapp:sha256-abc123.sig  # Signature
registry.example.com/myapp:sha256-abc123.att  # Attestations
```

---

## Attestations

### Creating SBOM Attestation

```bash
# Generate SBOM
syft myapp:v1.2.3 -o spdx-json > sbom.spdx.json

# Create attestation
cosign attest \
  --predicate sbom.spdx.json \
  --type spdx \
  --key cosign.key \
  myapp:v1.2.3

# Verify attestation
cosign verify-attestation \
  --type spdx \
  --key cosign.pub \
  myapp:v1.2.3
```

### Creating Vulnerability Scan Attestation

```bash
# Scan image
trivy image --format json --output scan-results.json myapp:v1.2.3

# Create attestation
cosign attest \
  --predicate scan-results.json \
  --type vuln \
  --key cosign.key \
  myapp:v1.2.3
```

### Creating Custom Attestations

```bash
# Create custom predicate
cat > test-results.json <<EOF
{
  "passed": true,
  "tests_run": 150,
  "tests_passed": 150,
  "tests_failed": 0,
  "timestamp": "2024-01-15T10:30:00Z"
}
EOF

# Attest
cosign attest \
  --predicate test-results.json \
  --type https://example.com/test-results/v1 \
  --key cosign.key \
  myapp:v1.2.3
```

---

## Supply Chain Security

### Build Process

```
1. Source Code (Git)
   ↓
2. Build (GitHub Actions / CI)
   ↓
3. Container Image
   ↓
4. Scan (Trivy)
   ↓
5. Generate SBOM (Syft)
   ↓
6. Sign Image (Cosign)
   ↓
7. Generate Provenance
   ↓
8. Push to Registry
   ↓
9. Deploy to Kubernetes
   ↓
10. Verify Signatures
```

### CI/CD Pipeline Example

```yaml
name: Secure Build Pipeline

on:
  push:
    branches: [main]
    tags: ['v*']

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Build image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: false
        tags: myapp:${{ github.sha }}
        load: true

    - name: Scan for vulnerabilities
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: myapp:${{ github.sha }}
        format: 'json'
        output: 'scan-results.json'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'

    - name: Generate SBOM
      run: |
        syft myapp:${{ github.sha }} -o spdx-json > sbom.spdx.json

    - name: Login to registry
      uses: docker/login-action@v2
      with:
        registry: registry.example.com
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Push image
      run: |
        docker tag myapp:${{ github.sha }} registry.example.com/myapp:${{ github.ref_name }}
        docker push registry.example.com/myapp:${{ github.ref_name }}

    - name: Install Cosign
      uses: sigstore/cosign-installer@v3

    - name: Sign image
      run: |
        cosign sign --yes registry.example.com/myapp:${{ github.ref_name }}

    - name: Attest SBOM
      run: |
        cosign attest --yes \
          --predicate sbom.spdx.json \
          --type spdx \
          registry.example.com/myapp:${{ github.ref_name }}

    - name: Attest vulnerability scan
      run: |
        cosign attest --yes \
          --predicate scan-results.json \
          --type vuln \
          registry.example.com/myapp:${{ github.ref_name }}

    - name: Generate provenance
      uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.9.0
```

---

## Verification Workflows

### Pre-Deployment Verification

```bash
#!/bin/bash
# verify-image.sh

IMAGE="$1"

echo "Verifying $IMAGE..."

# 1. Verify signature
echo "1. Verifying signature..."
if ! cosign verify --key cosign.pub "$IMAGE"; then
  echo "ERROR: Signature verification failed"
  exit 1
fi

# 2. Verify SBOM attestation exists
echo "2. Verifying SBOM attestation..."
if ! cosign verify-attestation --type spdx --key cosign.pub "$IMAGE"; then
  echo "ERROR: SBOM attestation verification failed"
  exit 1
fi

# 3. Verify vulnerability scan
echo "3. Verifying vulnerability scan..."
if ! cosign verify-attestation --type vuln --key cosign.pub "$IMAGE"; then
  echo "ERROR: Vulnerability scan attestation verification failed"
  exit 1
fi

# 4. Check scan results
echo "4. Checking scan results..."
SCAN_RESULTS=$(cosign verify-attestation --type vuln --key cosign.pub "$IMAGE" | jq -r '.payload' | base64 -d | jq)
CRITICAL=$(echo "$SCAN_RESULTS" | jq '.predicate.scanner.result.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL") | length')

if [ "$CRITICAL" -gt 0 ]; then
  echo "ERROR: Found $CRITICAL critical vulnerabilities"
  exit 1
fi

echo "✓ All verifications passed"
```

### Kubernetes Admission Control

```yaml
# Kyverno policy to verify signatures
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: enforce
  webhookTimeoutSeconds: 30
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
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----

  - name: verify-sbom
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestations:
      - predicateType: https://spdx.dev/Document
        attestors:
        - count: 1
          entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                -----END PUBLIC KEY-----
```

---

## Policy Enforcement

### Requiring Signatures

```yaml
# Require all images to be signed
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-signature
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              ...
              -----END PUBLIC KEY-----
```

### Requiring SBOM

```yaml
# Require SBOM attestation
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom
spec:
  validationFailureAction: enforce
  rules:
  - name: check-sbom-attestation
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestations:
      - predicateType: https://spdx.dev/Document
        attestors:
        - count: 1
          entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                ...
                -----END PUBLIC KEY-----
```

### Blocking Vulnerable Images

```yaml
# Block images with critical vulnerabilities
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-vulnerable-images
spec:
  validationFailureAction: enforce
  rules:
  - name: check-vulnerabilities
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestations:
      - predicateType: https://cosign.sigstore.dev/attestation/vuln/v1
        conditions:
        - all:
          - key: "{{ results[?name=='trivy'].Vulnerabilities[?Severity=='CRITICAL'] | length(@) }}"
            operator: Equals
            value: 0
        attestors:
        - count: 1
          entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                ...
                -----END PUBLIC KEY-----
```

---

## Best Practices

### Do's

1. **Generate SBOM for all images**
   ```bash
   syft myapp:v1.2.3 -o spdx-json > sbom.spdx.json
   ```

2. **Sign all images**
   ```bash
   cosign sign --key cosign.key myapp:v1.2.3
   ```

3. **Create attestations for scans**
   ```bash
   cosign attest --predicate scan.json --type vuln myapp:v1.2.3
   ```

4. **Verify signatures before deployment**
   ```bash
   cosign verify --key cosign.pub myapp:v1.2.3
   ```

5. **Store SBOMs in registry**
   ```bash
   cosign attach sbom --sbom sbom.spdx.json myapp:v1.2.3
   ```

6. **Use keyless signing when possible**
   ```bash
   COSIGN_EXPERIMENTAL=1 cosign sign myapp:v1.2.3
   ```

### Don'ts

1. **Don't skip vulnerability scanning**
2. **Don't deploy unsigned images**
3. **Don't hardcode private keys**
4. **Don't ignore SBOM generation**
5. **Don't skip provenance**

---

## References

- [Security Guide](./security.md)
- [Deployment Guide](./deployment.md)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore Documentation](https://docs.sigstore.dev/)
- [in-toto Attestation Framework](https://in-toto.io/)
- [SPDX Specification](https://spdx.github.io/spdx-spec/)
- [CycloneDX Specification](https://cyclonedx.org/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
