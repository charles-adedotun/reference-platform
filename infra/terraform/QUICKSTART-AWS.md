# AWS Terraform Quick Start Guide

This is a quick reference for deploying AWS infrastructure using the Terraform configurations.

## Prerequisites

- Terraform >= 1.6 (recommend 1.9.0+ for S3 native locking)
- AWS CLI configured
- AWS credentials with appropriate permissions

## File Structure Overview

```
terraform/
├── modules/aws/              # Reusable modules
│   ├── network/             # VPC with EKS tags
│   ├── eks/                 # EKS v21 with IRSA
│   ├── iam-oidc/           # GitHub Actions OIDC
│   └── state-backend/       # S3 state bucket
├── environments/aws/
│   ├── dev/                 # Dev environment
│   ├── staging/             # Staging environment
│   └── prod/                # Production environment
└── bootstrap/aws/           # Create state buckets
```

## Step-by-Step Deployment

### 1. Bootstrap State Backend (One-Time Setup)

```bash
# Navigate to bootstrap directory
cd bootstrap/aws

# Update configuration
vi terraform.tfvars
# Change: project_name = "my-platform" to your project name

# Deploy state buckets
terraform init
terraform apply
```

**Creates**:
- `my-platform-terraform-state-dev`
- `my-platform-terraform-state-staging`
- `my-platform-terraform-state-prod`

### 2. Configure Development Environment

```bash
cd ../../environments/aws/dev

# Update variables
vi terraform.tfvars
```

**Required updates**:
```hcl
project_name = "your-project-name"
aws_region   = "us-east-1"  # or your preferred region

# Update GitHub repositories
github_repositories = [
  "repo:charles-adedotun/reference-platform:ref:refs/heads/main"
]

# If using ECR, update ARNs
ecr_repository_arns = [
  "arn:aws:ecr:us-east-1:123456789012:repository/your-app"
]
```

### 3. Enable S3 Native Locking (Optional but Recommended)

```bash
vi backend.tf
```

**Uncomment this line**:
```hcl
use_lockfile = true
```

**Benefits**:
- No DynamoDB table needed
- Cost savings (~$0.25-$1/month)
- Requires Terraform >= 1.9.0

### 4. Deploy Development Environment

```bash
# Initialize with remote backend
terraform init -reconfigure

# Review what will be created
terraform plan

# Deploy infrastructure
terraform apply
```

**This creates** (~15-20 minutes):
- VPC with public/private subnets
- EKS cluster (Kubernetes 1.31)
- Managed node group (2 t3.medium nodes)
- GitHub Actions OIDC provider
- IAM roles and policies

### 5. Configure kubectl

```bash
# Get cluster credentials
aws eks update-kubeconfig --region us-east-1 --name your-project-dev

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

### 6. Deploy Staging (Optional)

```bash
cd ../staging

# Update terraform.tfvars
vi terraform.tfvars

# Enable S3 locking
vi backend.tf  # Uncomment use_lockfile = true

# Deploy
terraform init -reconfigure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name your-project-staging
```

### 7. Deploy Production (When Ready)

```bash
cd ../prod

# Update terraform.tfvars
vi terraform.tfvars

# Enable S3 locking
vi backend.tf  # Uncomment use_lockfile = true

# Deploy
terraform init -reconfigure
terraform apply

# Configure kubectl (from VPN/bastion if private endpoint only)
aws eks update-kubeconfig --region us-east-1 --name your-project-prod
```

## Important Configuration Differences

### Development
```hcl
single_nat_gateway = true          # Cost savings
node_instance_types = ["t3.medium"]
node_min_size = 1
node_max_size = 3
cluster_endpoint_public_access = true
```

### Staging
```hcl
single_nat_gateway = false         # NAT per AZ
node_instance_types = ["t3.large"]
node_min_size = 2
node_max_size = 6
cluster_endpoint_public_access = true
```

### Production
```hcl
single_nat_gateway = false         # NAT per AZ
node_instance_types = ["m5.xlarge"]
node_min_size = 3
node_max_size = 10
cluster_endpoint_public_access = false  # Private only!
```

## GitHub Actions Integration

### 1. Get IAM Role ARN

```bash
cd environments/aws/dev
terraform output github_actions_role_arn
```

### 2. Add to GitHub Secrets

In your GitHub repository:
- Go to Settings > Secrets and variables > Actions
- Add new secret: `AWS_ROLE_ARN`
- Value: (paste the role ARN)

### 3. Use in Workflow

```yaml
name: Deploy to EKS
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region us-east-1 | \
            docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region us-east-1 --name my-platform-dev

      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/
```

## Common Commands

### View Outputs
```bash
terraform output                     # All outputs
terraform output cluster_name        # Specific output
terraform output -json              # JSON format
```

### Update Infrastructure
```bash
terraform plan                      # Preview changes
terraform apply                     # Apply changes
terraform apply -auto-approve       # Skip confirmation
```

### Destroy Infrastructure
```bash
terraform destroy                   # Destroy environment
terraform destroy -target=module.network  # Destroy specific module
```

### State Management
```bash
terraform state list                # List resources
terraform state show <resource>     # Show resource details
terraform refresh                   # Refresh state
```

## Useful Outputs

Each environment provides these outputs:

```bash
# Network
terraform output vpc_id
terraform output private_subnet_ids
terraform output public_subnet_ids

# EKS
terraform output cluster_name
terraform output cluster_endpoint
terraform output cluster_oidc_issuer_url

# GitHub Actions
terraform output github_actions_role_arn
terraform output github_oidc_provider_arn

# kubectl command
terraform output configure_kubectl
```

## Cost Estimates

### Development Environment
- **NAT Gateway**: $32/month (1 gateway)
- **EKS Control Plane**: $73/month
- **EC2 Nodes**: ~$60/month (2 x t3.medium)
- **Data Transfer**: ~$10/month
- **Total**: ~$175/month

### Staging Environment
- **NAT Gateways**: $96/month (3 gateways)
- **EKS Control Plane**: $73/month
- **EC2 Nodes**: ~$180/month (3 x t3.large)
- **Data Transfer**: ~$20/month
- **Total**: ~$370/month

### Production Environment
- **NAT Gateways**: $96/month (3 gateways)
- **EKS Control Plane**: $73/month
- **EC2 Nodes**: ~$575/month (5 x m5.xlarge)
- **Data Transfer**: ~$50/month
- **Total**: ~$795/month

## Troubleshooting

### Backend Init Error
```bash
# Error: Backend configuration changed
terraform init -reconfigure
```

### State Lock Error
```bash
# With S3 native locking
terraform force-unlock <lock-id>

# If using DynamoDB, check the locks table in AWS Console
```

### kubectl Access Error
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Verify AWS credentials
aws sts get-caller-identity

# Check cluster endpoint access
terraform output cluster_endpoint
```

### Node Group Not Starting
```bash
# Check AWS Console > EKS > Cluster > Compute
# Common issues:
# - Insufficient EC2 capacity in region
# - Service quota limits
# - IAM role issues

# Check node group status
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name>
```

### GitHub Actions OIDC Error
```bash
# Verify role ARN
terraform output github_actions_role_arn

# Check trust policy
aws iam get-role --role-name <role-name>

# Verify repository format in terraform.tfvars
# Must be: "repo:org/repo:ref:refs/heads/branch"
```

## Module Documentation

For detailed module documentation, see:
- **Network**: `infra/terraform/modules/aws/network/`
- **EKS**: `infra/terraform/modules/aws/eks/`
- **IAM OIDC**: `infra/terraform/modules/aws/iam-oidc/`
- **State Backend**: `infra/terraform/modules/aws/state-backend/`

For comprehensive documentation, see:
- **README-AWS.md**: Complete guide with architecture details
- **bootstrap/aws/README.md**: Bootstrap-specific documentation

## Security Checklist

Before deploying to production:

- [ ] Review and update `terraform.tfvars` for each environment
- [ ] Update GitHub repository identifiers
- [ ] Set `cluster_endpoint_public_access = false` for prod
- [ ] Review IAM permissions in iam-oidc module
- [ ] Enable encryption at rest for EBS volumes
- [ ] Configure VPC flow logs (optional)
- [ ] Set up AWS CloudWatch logging
- [ ] Review security group rules
- [ ] Enable AWS GuardDuty (optional)
- [ ] Configure backup policies
- [ ] Document disaster recovery procedures

## Next Steps

After deployment:

1. **Install Kubernetes addons**:
   - Ingress controller (nginx, ALB controller)
   - Cert-manager for TLS
   - External-DNS for route53
   - Metrics server
   - Prometheus/Grafana

2. **Configure observability**:
   - CloudWatch Container Insights
   - Application logging
   - Distributed tracing

3. **Set up CI/CD**:
   - GitHub Actions workflows
   - ArgoCD or Flux for GitOps
   - Image scanning

4. **Implement security**:
   - Pod Security Standards
   - Network policies
   - Secret management (AWS Secrets Manager)
   - IRSA for application pods

5. **Configure autoscaling**:
   - Horizontal Pod Autoscaler (HPA)
   - Cluster Autoscaler or Karpenter
   - Vertical Pod Autoscaler (VPA)

## Support

For issues or questions:
1. Check module variables and outputs
2. Review Terraform plan before apply
3. Check AWS CloudWatch logs
4. Review EKS cluster events
5. Consult AWS documentation

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [terraform-aws-modules](https://github.com/terraform-aws-modules)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
