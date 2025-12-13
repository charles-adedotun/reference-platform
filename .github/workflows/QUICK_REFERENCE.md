# Quick Reference - Required Secrets

## GitHub Repository Secrets

### AWS Terraform (terraform-aws.yml)
```bash
# Development
AWS_ROLE_ARN_DEV=arn:aws:iam::123456789:role/github-actions-role
TF_STATE_BUCKET_DEV=terraform-state-dev

# Staging  
AWS_ROLE_ARN_STAGING=arn:aws:iam::123456789:role/github-actions-role
TF_STATE_BUCKET_STAGING=terraform-state-staging

# Production
AWS_ROLE_ARN_PROD=arn:aws:iam::123456789:role/github-actions-role
TF_STATE_BUCKET_PROD=terraform-state-prod
```

### GCP Terraform (terraform-gcp.yml)
```bash
# Development
GCP_WORKLOAD_IDENTITY_PROVIDER_DEV=projects/123/locations/global/workloadIdentityPools/...
GCP_SERVICE_ACCOUNT_DEV=github-actions@project.iam.gserviceaccount.com
GCP_PROJECT_ID_DEV=my-gcp-project-dev
TF_STATE_BUCKET_DEV=terraform-state-dev

# Staging
GCP_WORKLOAD_IDENTITY_PROVIDER_STAGING=projects/123/locations/global/workloadIdentityPools/...
GCP_SERVICE_ACCOUNT_STAGING=github-actions@project.iam.gserviceaccount.com
GCP_PROJECT_ID_STAGING=my-gcp-project-staging
TF_STATE_BUCKET_STAGING=terraform-state-staging

# Production
GCP_WORKLOAD_IDENTITY_PROVIDER_PROD=projects/123/locations/global/workloadIdentityPools/...
GCP_SERVICE_ACCOUNT_PROD=github-actions@project.iam.gserviceaccount.com
GCP_PROJECT_ID_PROD=my-gcp-project-prod
TF_STATE_BUCKET_PROD=terraform-state-prod
```

### Live Status (live-status.yml)
```bash
# Required
HEALTH_CHECK_URL=https://api.example.com/health

# Optional
ADDITIONAL_ENDPOINTS=Dashboard|https://dashboard.example.com,API|https://api.example.com/v1/health
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Setting Secrets via CLI

```bash
# Using GitHub CLI
gh secret set SECRET_NAME --body "secret-value"

# Or from file
gh secret set SECRET_NAME < secret.txt

# List all secrets
gh secret list
```

## Environment Setup

```bash
# Create environments
gh api repos/{owner}/{repo}/environments/dev -X PUT
gh api repos/{owner}/{repo}/environments/staging -X PUT
gh api repos/{owner}/{repo}/environments/prod -X PUT
```

## Quick Commands

```bash
# Trigger workflow manually
gh workflow run ci.yml
gh workflow run terraform-aws.yml -f environment=dev -f action=plan

# View workflow status
gh run list --workflow=ci.yml
gh run watch

# View logs
gh run view --log

# Download artifacts
gh run download <run-id>

# Cancel workflow
gh run cancel <run-id>
```

## File Structure

```
.github/
├── workflows/
│   ├── ci.yml                 # Main CI pipeline
│   ├── security.yml          # Security scanning
│   ├── terraform-aws.yml     # AWS infrastructure
│   ├── terraform-gcp.yml     # GCP infrastructure
│   ├── release.yml           # Release automation
│   ├── live-status.yml       # Health monitoring
│   └── README.md             # Full documentation
└── dependabot.yml            # Dependency updates
```

## Common Tasks

### Deploy to AWS Dev
```bash
# Push to main branch (auto-deploys after plan)
git push origin main

# Or manually trigger
gh workflow run terraform-aws.yml -f environment=dev -f action=apply
```

### Create Release
```bash
# Tag and push
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Release workflow runs automatically
```

### Check Security
```bash
# View security alerts
gh api repos/{owner}/{repo}/code-scanning/alerts

# Trigger manual security scan
gh workflow run security.yml
```

### Update Status Page
```bash
# Manually trigger health check
gh workflow run live-status.yml
```

## Workflow Triggers

| Workflow | Push | PR | Tag | Schedule | Manual |
|----------|------|----|----|----------|--------|
| ci.yml | ✅ | ✅ | ❌ | ❌ | ❌ |
| security.yml | ✅ | ✅ | ❌ | ✅ Weekly | ✅ |
| terraform-aws.yml | ✅* | ✅* | ❌ | ❌ | ✅ |
| terraform-gcp.yml | ✅* | ✅* | ❌ | ❌ | ✅ |
| release.yml | ❌ | ❌ | ✅ v* | ❌ | ✅ |
| live-status.yml | ❌ | ❌ | ❌ | ✅ Every 6h | ✅ |

*Only on paths: terraform/{aws,gcp}/**

## Permissions Required

Enable in Settings → Actions → General:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

## Branch Protection

Recommended for `main` branch:
- ✅ Require pull request reviews (1-2 reviewers)
- ✅ Require status checks: Lint, Test, Build
- ✅ Require branches to be up to date
- ✅ Require conversation resolution
- ✅ Include administrators
