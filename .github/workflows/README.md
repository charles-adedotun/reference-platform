# GitHub Actions Workflows - Setup Guide

This directory contains complete CI/CD pipelines for the reference platform.

## Workflows Overview

### 1. ci.yml - Main CI Pipeline
**Triggers:** Push/PR to main branch

**Jobs:**
- **Lint**: Runs golangci-lint, go fmt, and go vet
- **Test**: Executes tests with race detection and uploads coverage to Codecov
- **Build**: Builds Go binaries and Docker images (caches for efficiency)
- **Helm Lint**: Validates Helm charts with helm lint and kubeconform

**Key Features:**
- Go 1.23 setup with caching
- Docker build with GitHub Actions cache
- No Docker push on PRs (security best practice)
- Parallel job execution for speed

---

### 2. security.yml - Security Scanning
**Triggers:** Push to main, PRs, weekly schedule (Mondays), manual dispatch

**Jobs:**
- **CodeQL**: Go code analysis with security-extended queries
- **Trivy Repository Scan**: Filesystem vulnerability scanning
- **Trivy Config Scan**: Infrastructure-as-Code security checks
- **Trivy Container Scan**: Docker image vulnerability scanning (main branch only)
- **Gitleaks**: Secret detection in git history
- **govulncheck**: Go-specific vulnerability checking
- **Dependency Review**: PR-based dependency analysis

**Key Features:**
- All scans upload SARIF results to GitHub Security tab
- Multiple scanning tools for comprehensive coverage
- Weekly automated scans
- License compliance checking (blocks GPL-2.0, GPL-3.0)

---

### 3. terraform-aws.yml - AWS Infrastructure
**Triggers:** Push/PR to main (terraform/aws/** paths), manual dispatch

**Jobs:**
- **Terraform**: Matrix job for dev/staging/prod environments
  - Format checking
  - Initialization with S3 backend
  - Validation
  - Plan (with PR comments)
  - Apply (main branch only or manual)
  - Destroy (manual only)
- **TFSec**: Terraform security scanning
- **Checkov**: Additional IaC security analysis

**Key Features:**
- OIDC authentication with AWS (no static credentials)
- Environment-specific secrets: `AWS_ROLE_ARN_DEV`, `AWS_ROLE_ARN_STAGING`, `AWS_ROLE_ARN_PROD`
- State bucket secrets: `TF_STATE_BUCKET_DEV`, etc.
- Plan comments on PRs
- Environment protection rules
- Security scans with SARIF upload

**Required Secrets:**
- `AWS_ROLE_ARN_DEV` / `AWS_ROLE_ARN_STAGING` / `AWS_ROLE_ARN_PROD`
- `TF_STATE_BUCKET_DEV` / `TF_STATE_BUCKET_STAGING` / `TF_STATE_BUCKET_PROD`

---

### 4. terraform-gcp.yml - GCP Infrastructure
**Triggers:** Push/PR to main (terraform/gcp/** paths), manual dispatch

**Jobs:**
- **Terraform**: Matrix job for dev/staging/prod environments
  - Format checking
  - Initialization with GCS backend
  - Validation
  - Plan (with PR comments)
  - Apply (main branch only or manual)
  - Destroy (manual only)
- **TFSec**: Terraform security scanning
- **Checkov**: Additional IaC security analysis

**Key Features:**
- Workload Identity Federation (no service account keys)
- Environment-specific secrets: `GCP_WORKLOAD_IDENTITY_PROVIDER_*`, `GCP_SERVICE_ACCOUNT_*`
- State bucket secrets: `TF_STATE_BUCKET_*`
- Project ID per environment: `GCP_PROJECT_ID_*`
- Plan comments on PRs
- Security scans with SARIF upload

**Required Secrets:**
- `GCP_WORKLOAD_IDENTITY_PROVIDER_DEV` / `GCP_WORKLOAD_IDENTITY_PROVIDER_STAGING` / `GCP_WORKLOAD_IDENTITY_PROVIDER_PROD`
- `GCP_SERVICE_ACCOUNT_DEV` / `GCP_SERVICE_ACCOUNT_STAGING` / `GCP_SERVICE_ACCOUNT_PROD`
- `GCP_PROJECT_ID_DEV` / `GCP_PROJECT_ID_STAGING` / `GCP_PROJECT_ID_PROD`
- `TF_STATE_BUCKET_DEV` / `TF_STATE_BUCKET_STAGING` / `TF_STATE_BUCKET_PROD`

---

### 5. release.yml - Release Pipeline
**Triggers:** Tag push (v*), manual dispatch

**Jobs:**
- **Build and Push**: Multi-arch Docker images (amd64/arm64) to ghcr.io
- **Generate SBOM**: Creates SPDX and CycloneDX SBOMs with Syft
- **Sign Image**: Cosign signing with keyless signatures
- **Scan Image**: Trivy vulnerability scan of released image
- **Create Release**: GitHub release with binaries and SBOMs
- **Update Deployment**: Automated PR to update manifests

**Key Features:**
- Multi-platform builds (Linux/Darwin/Windows, amd64/arm64)
- GitHub artifact attestation for provenance
- Cosign signing (keyless with Sigstore)
- SBOM generation and attachment
- Automated changelog generation
- SHA256 checksums
- Semantic versioning support
- Prerelease detection (alpha/beta/rc)
- Automated deployment manifest updates

**Release Types:**
- `v1.2.3` - Production release
- `v1.2.3-rc1` - Release candidate
- `v1.2.3-beta1` - Beta release
- `v1.2.3-alpha1` - Alpha release

---

### 6. live-status.yml - Health Monitoring
**Triggers:** Every 6 hours, manual dispatch

**Jobs:**
- **Check Status**: Curl health endpoints and update status page
- **Notify Slack**: Send alerts on failures (optional)

**Key Features:**
- Configurable health check URLs via secrets
- Multiple endpoint support (comma-separated)
- Automatic LIVE_STATUS.md updates
- Git commit and push of status changes
- Issue creation/update on service failures
- Slack webhook notifications (optional)
- Response time tracking
- Status badges (✅/⚠️/❌)

**Required Secrets:**
- `HEALTH_CHECK_URL` - Main health endpoint (default: https://example.com/health)
- `ADDITIONAL_ENDPOINTS` - Optional CSV format: "Name1|url1,Name2|url2"
- `SLACK_WEBHOOK_URL` - Optional Slack webhook for alerts

**Status File Format:**
```markdown
# Live Service Status

Last updated: **2025-12-12 18:00:00 UTC**

| Service | Status | Details | Response Time |
|---------|--------|---------|---------------|
| Main API | ✅ Operational | HTTP 200 | 0.123s |

**Overall Status:** ✅ All Systems Operational
```

---

## Dependabot Configuration

Located at `.github/dependabot.yml`, this configures automated dependency updates:

**Package Ecosystems:**
- **Go modules**: Weekly updates (Mondays 9:00 UTC)
- **Docker images**: Weekly updates (Mondays 9:00 UTC)
- **GitHub Actions**: Weekly updates (Mondays 9:00 UTC)
- **Terraform (AWS)**: Weekly updates (Tuesdays 9:00 UTC)
- **Terraform (GCP)**: Weekly updates (Tuesdays 9:00 UTC)
- **Helm charts**: Weekly updates (Wednesdays 9:00 UTC)

**Features:**
- Grouped minor/patch updates to reduce PR noise
- Automatic labeling and assignment
- Conventional commit messages (`chore(deps):`)
- Pull request limits to avoid overwhelming reviewers
- Team reviewers and assignees

---

## Setup Instructions

### 1. Repository Settings

**Enable required permissions:**
- Settings → Actions → General → Workflow permissions
  - ✅ Read and write permissions
  - ✅ Allow GitHub Actions to create and approve pull requests

**Configure environments:**
- Settings → Environments → Create: `dev`, `staging`, `prod`
- Add protection rules for `staging` and `prod` (require reviewers)

### 2. Configure Secrets

**For AWS Terraform:**
```bash
# Per environment
gh secret set AWS_ROLE_ARN_DEV --body "arn:aws:iam::123456789:role/github-actions-role"
gh secret set TF_STATE_BUCKET_DEV --body "my-terraform-state-dev"

# Repeat for STAGING and PROD
```

**For GCP Terraform:**
```bash
# Per environment
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER_DEV --body "projects/123/locations/global/workloadIdentityPools/..."
gh secret set GCP_SERVICE_ACCOUNT_DEV --body "github-actions@project.iam.gserviceaccount.com"
gh secret set GCP_PROJECT_ID_DEV --body "my-gcp-project-dev"
gh secret set TF_STATE_BUCKET_DEV --body "my-terraform-state-dev"

# Repeat for STAGING and PROD
```

**For Live Status:**
```bash
gh secret set HEALTH_CHECK_URL --body "https://api.example.com/health"
gh secret set ADDITIONAL_ENDPOINTS --body "Dashboard|https://dashboard.example.com,API|https://api.example.com/health"
gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/services/..."  # Optional
```

### 3. AWS OIDC Setup

Create IAM role with trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
```

### 4. GCP Workload Identity Setup

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-actions \
  --location="global" \
  --description="GitHub Actions Pool"

# Create Provider
gcloud iam workload-identity-pools providers create-oidc github \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Bind Service Account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/OWNER/REPO"
```

### 5. Dependabot Team Setup

Update `.github/dependabot.yml` to replace `platform-team` with your team name or individual reviewers:
```yaml
reviewers:
  - "your-team-name"
assignees:
  - "your-username"
```

### 6. Branch Protection Rules

Set up branch protection for `main`:
- Require pull request reviews
- Require status checks to pass:
  - `Lint`
  - `Test`
  - `Build`
  - `CodeQL Analysis`
- Require branches to be up to date
- Include administrators

---

## Workflow Customization

### Adjusting Scan Schedules

**Security scans** (currently weekly on Monday):
```yaml
schedule:
  - cron: '0 0 * * 1'  # Change day: 0=Sunday, 1=Monday, etc.
```

**Live status** (currently every 6 hours):
```yaml
schedule:
  - cron: '0 */6 * * *'  # Change to */4 for 4 hours, */12 for 12 hours
```

### Adding Custom Endpoints

Edit `live-status.yml` to add hardcoded endpoints or use the `ADDITIONAL_ENDPOINTS` secret.

### Customizing Build Targets

Edit `release.yml` to add/remove build architectures:
```yaml
- name: Build release binaries
  run: |
    GOOS=linux GOARCH=riscv64 go build -o dist/app-linux-riscv64 ./cmd/...
```

### Docker Build Platforms

Edit `release.yml` to change platforms:
```yaml
platforms: linux/amd64,linux/arm64,linux/arm/v7
```

---

## Monitoring and Debugging

### View Workflow Runs
```bash
gh run list --workflow=ci.yml
gh run view <run-id>
gh run watch <run-id>
```

### Check Security Alerts
- Navigate to: Security → Code scanning alerts
- Navigate to: Security → Dependabot alerts

### Test Workflows Locally
Use [act](https://github.com/nektos/act) for local testing:
```bash
act -j lint                    # Test lint job
act -j test                    # Test test job
act push                       # Simulate push event
act pull_request               # Simulate PR event
```

### Enable Debug Logging
Add secrets for verbose logging:
```bash
gh secret set ACTIONS_RUNNER_DEBUG --body "true"
gh secret set ACTIONS_STEP_DEBUG --body "true"
```

---

## Security Best Practices

✅ **Implemented:**
- OIDC authentication (no static credentials)
- Minimal permissions per job
- Dependabot for automatic updates
- Multiple security scanning tools
- Secret scanning with Gitleaks
- SBOM generation for transparency
- Image signing with Cosign
- Artifact attestation
- No cache poisoning (proper cache isolation)

⚠️ **Recommendations:**
1. Enable branch protection rules
2. Require code review for all PRs
3. Set up environment protection for prod
4. Rotate secrets regularly
5. Monitor security alerts daily
6. Review Dependabot PRs promptly
7. Keep actions versions updated
8. Use repository environments for secrets isolation

---

## Troubleshooting

### Common Issues

**1. Terraform auth fails:**
- Verify OIDC provider is configured
- Check role trust policy allows your repo
- Ensure secret names match exactly

**2. Docker build fails:**
- Check Dockerfile exists in repo root
- Verify Go module setup is correct
- Check for build cache issues

**3. Helm lint fails:**
- Ensure charts/ directory exists
- Validate Chart.yaml format
- Check template syntax

**4. Live status commits fail:**
- Verify GITHUB_TOKEN has write permissions
- Check branch protection doesn't block bot commits
- Use `[skip ci]` in commit message to avoid loops

**5. Release workflow fails:**
- Verify tag format is `v*` (e.g., v1.0.0)
- Check GITHUB_TOKEN permissions
- Ensure go.mod exists

---

## Workflow Diagram

```
Push/PR to main
    ├─→ ci.yml (lint, test, build, helm-lint)
    ├─→ security.yml (CodeQL, Trivy, Gitleaks, etc.)
    └─→ terraform-*.yml (plan only on PR)

Push to main (after merge)
    └─→ terraform-*.yml (apply with approval)

Tag push (v*)
    └─→ release.yml
        ├─→ Build multi-arch images
        ├─→ Generate SBOM
        ├─→ Sign with Cosign
        ├─→ Create GitHub release
        └─→ Update deployment manifests

Schedule (weekly)
    └─→ security.yml (full security scan)

Schedule (every 6h)
    └─→ live-status.yml (health checks)

Dependabot (weekly)
    └─→ Automated dependency PRs
```

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [OIDC with GCP](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform)
- [Dependabot Configuration](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [CodeQL Queries](https://codeql.github.com/codeql-query-help/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [SLSA Framework](https://slsa.dev/)

---

**Created:** 2025-12-12  
**Workflows Version:** 1.0  
**Maintained by:** Platform Team
