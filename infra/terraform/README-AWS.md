# AWS Terraform Infrastructure

Complete Terraform configuration for deploying AWS infrastructure including VPC, EKS, and GitHub Actions OIDC integration.

## Directory Structure

```
terraform/
├── modules/aws/              # Reusable Terraform modules
│   ├── network/             # VPC, subnets, NAT gateways
│   ├── eks/                 # EKS cluster with managed node groups
│   ├── iam-oidc/           # GitHub Actions OIDC provider
│   └── state-backend/       # S3 bucket for Terraform state
├── environments/aws/         # Environment-specific configurations
│   ├── dev/                 # Development environment
│   ├── staging/             # Staging environment
│   └── prod/                # Production environment
└── bootstrap/aws/           # Bootstrap state backend (run once)
```

## Features

### Network Module (`modules/aws/network/`)
- VPC using `terraform-aws-modules/vpc/aws` v5.x
- Public and private subnets across multiple AZs
- NAT Gateways for private subnet internet access
- EKS-specific subnet tags for load balancer placement
- DNS support enabled

### EKS Module (`modules/aws/eks/`)
- EKS cluster using `terraform-aws-modules/eks/aws` v21.x
- Managed node groups with configurable instance types
- IRSA (IAM Roles for Service Accounts) enabled
- Cluster addons: CoreDNS, kube-proxy, VPC-CNI, EBS CSI driver
- Security groups for cluster and nodes
- OIDC provider for Kubernetes service accounts

### IAM OIDC Module (`modules/aws/iam-oidc/`)
- GitHub Actions OIDC provider setup
- IAM role with least-privilege policies
- Configurable permissions for:
  - ECR (push/pull container images)
  - EKS (describe cluster)
  - S3 (artifacts storage)
- Repository-based access control

### State Backend Module (`modules/aws/state-backend/`)
- S3 bucket with versioning enabled
- Server-side encryption (AES256 or KMS)
- Public access blocked
- Lifecycle policies for old versions
- Optional DynamoDB table for legacy locking

## S3 Native State Locking

**IMPORTANT**: S3 native state locking is **OPT-IN** via `use_lockfile=true` in the backend configuration.

### Benefits
- No DynamoDB table required (cost savings ~$0.25-$1/month per environment)
- Simpler infrastructure
- Built-in locking using S3 conditional writes
- Available in Terraform >= 1.9.0

### How to Enable
In each environment's `backend.tf`, uncomment:
```hcl
use_lockfile = true
```

### Legacy DynamoDB Locking
If you prefer DynamoDB for state locking:
1. Set `create_dynamodb_table = true` in `bootstrap/aws/terraform.tfvars`
2. Add `dynamodb_table` to backend configuration in each environment

## Quick Start

### Prerequisites

1. **Terraform** >= 1.6 installed
2. **AWS CLI** configured with appropriate credentials
3. **IAM Permissions** for creating VPC, EKS, S3, IAM resources

### Step 1: Bootstrap State Backend

First, create the S3 buckets for storing Terraform state:

```bash
cd bootstrap/aws

# Review and update configuration
vi terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply
```

This creates:
- `my-platform-terraform-state-dev`
- `my-platform-terraform-state-staging`
- `my-platform-terraform-state-prod`

See [bootstrap/aws/README.md](bootstrap/aws/README.md) for detailed instructions.

### Step 2: Deploy Development Environment

```bash
cd environments/aws/dev

# Update configuration
vi terraform.tfvars

# Update backend configuration
vi backend.tf
# Uncomment: use_lockfile = true (for S3 native locking)

# Initialize Terraform with remote backend
terraform init -reconfigure

# Review plan
terraform plan

# Apply changes
terraform apply
```

### Step 3: Configure kubectl

After EKS cluster is created:

```bash
aws eks update-kubeconfig --region us-east-1 --name my-platform-dev
kubectl get nodes
```

### Step 4: Deploy Staging and Production

Repeat Step 2 for staging and production environments:

```bash
cd environments/aws/staging
# Follow same steps as dev

cd environments/aws/prod
# Follow same steps as dev
```

## Environment Configuration

### Development (`environments/aws/dev/`)

**Optimized for cost**:
- Single NAT Gateway (shared across AZs)
- Smaller node instances (t3.medium)
- Fewer nodes (1-3)
- Public cluster endpoint enabled

```hcl
# Key settings in terraform.tfvars
single_nat_gateway = true
node_instance_types = ["t3.medium"]
node_min_size = 1
node_max_size = 3
cluster_endpoint_public_access = true
```

### Staging (`environments/aws/staging/`)

**Balanced for testing**:
- NAT Gateway per AZ (higher availability)
- Medium instances (t3.large)
- More nodes (2-6)
- Both public and private endpoints

```hcl
# Key settings in terraform.tfvars
single_nat_gateway = false
node_instance_types = ["t3.large"]
node_min_size = 2
node_max_size = 6
cluster_endpoint_public_access = true
```

### Production (`environments/aws/prod/`)

**Optimized for reliability**:
- NAT Gateway per AZ (high availability)
- Production instances (m5.xlarge)
- More nodes (3-10)
- Private endpoint only (for security)

```hcl
# Key settings in terraform.tfvars
single_nat_gateway = false
node_instance_types = ["m5.xlarge"]
node_min_size = 3
node_max_size = 10
cluster_endpoint_public_access = false  # Private only
```

## Configuration Reference

### Required Variables (All Environments)

```hcl
# AWS Configuration
aws_region   = "us-east-1"
project_name = "my-platform"

# Network
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# GitHub Actions OIDC
github_repositories = [
  "repo:your-org/your-repo:ref:refs/heads/main"
]
```

### GitHub Actions OIDC Configuration

The IAM OIDC module creates an IAM role that GitHub Actions can assume using OIDC. This eliminates the need for long-lived AWS credentials.

**Repository Format**:
```hcl
github_repositories = [
  "repo:org/repo:ref:refs/heads/main",        # Specific branch
  "repo:org/repo:ref:refs/heads/develop",     # Another branch
  "repo:org/repo:*",                          # All branches/tags
  "repo:org/repo:pull_request"                # Pull requests
]
```

**Permissions**:
```hcl
enable_github_ecr_access = true  # Push/pull container images
enable_github_eks_access = true  # Describe EKS cluster
enable_github_s3_access  = true  # Access S3 buckets

# Update with actual ARNs
ecr_repository_arns = [
  "arn:aws:ecr:us-east-1:123456789012:repository/my-app"
]
```

**Usage in GitHub Actions**:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

## Outputs

Each environment provides useful outputs:

```bash
terraform output

# Examples:
cluster_name              # EKS cluster name
cluster_endpoint          # EKS API endpoint
github_actions_role_arn   # ARN for GitHub Actions
configure_kubectl         # Command to configure kubectl
vpc_id                    # VPC identifier
```

## Module Version Constraints

All modules use appropriate version constraints:

```hcl
# Terraform version
terraform >= 1.6

# AWS Provider
hashicorp/aws ~> 5.0

# Community Modules
terraform-aws-modules/vpc/aws ~> 5.0
terraform-aws-modules/eks/aws ~> 21.0
terraform-aws-modules/iam/aws ~> 5.0
```

## Security Best Practices

1. **State Backend**:
   - S3 bucket encryption enabled
   - Versioning for state recovery
   - Public access blocked
   - Lifecycle policies for cleanup

2. **Network**:
   - Private subnets for EKS nodes
   - NAT Gateways for outbound internet
   - Security groups with least privilege

3. **EKS**:
   - IRSA for pod-level IAM permissions
   - Private endpoint for production
   - Node security groups
   - Encrypted EBS volumes

4. **IAM**:
   - OIDC for GitHub Actions (no long-lived keys)
   - Least-privilege policies
   - Repository-based access control

## Cost Optimization

### Development
- **Single NAT Gateway**: ~$32/month (vs $96 for 3)
- **Smaller instances**: t3.medium vs m5.xlarge
- **Fewer nodes**: 1-3 vs 3-10
- **Estimated cost**: ~$100-150/month

### Staging
- **NAT per AZ**: $96/month
- **Medium instances**: t3.large
- **Moderate scaling**: 2-6 nodes
- **Estimated cost**: ~$300-400/month

### Production
- **High availability**: NAT per AZ
- **Production instances**: m5.xlarge
- **Higher capacity**: 3-10 nodes
- **Estimated cost**: ~$500-800/month

**Additional costs**:
- Data transfer
- Load Balancers (created by Kubernetes)
- EBS volumes
- CloudWatch logs

## Troubleshooting

### Backend Configuration Issues

**Problem**: `Error: Backend initialization required`

**Solution**:
```bash
terraform init -reconfigure
```

### State Lock Issues

**Problem**: `Error acquiring the state lock`

**Solution with S3 native locking**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Solution with DynamoDB locking**:
```bash
# Check DynamoDB console for stuck locks
# Delete the lock item manually if needed
```

### EKS Access Issues

**Problem**: `error: You must be logged in to the server (Unauthorized)`

**Solution**:
```bash
aws eks update-kubeconfig --region us-east-1 --name my-platform-dev
```

### IAM Permissions

**Problem**: `AccessDenied` errors during apply

**Solution**: Ensure your IAM user/role has permissions for:
- VPC operations (ec2:*)
- EKS operations (eks:*)
- IAM operations (iam:*)
- S3 operations (s3:*)

## Upgrading

### Terraform Version
```bash
# Check current version
terraform version

# Upgrade providers
terraform init -upgrade
```

### Module Versions

Update version constraints in `versions.tf`:
```hcl
terraform-aws-modules/eks/aws ~> 22.0  # New version
```

Then run:
```bash
terraform init -upgrade
terraform plan
```

## Cleanup

To destroy an environment:

```bash
cd environments/aws/dev

# Destroy resources
terraform destroy

# Confirm with: yes
```

**Warning**: This will delete:
- EKS cluster and all workloads
- VPC and networking
- IAM roles
- Data may be lost!

To remove state backend:
```bash
cd bootstrap/aws
terraform destroy
```

## Additional Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [terraform-aws-modules/vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [terraform-aws-modules/eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [S3 Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review module documentation
3. Check AWS service quotas and limits
4. Verify IAM permissions

## License

See project LICENSE file.
