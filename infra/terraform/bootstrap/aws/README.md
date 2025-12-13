# AWS Terraform State Backend Bootstrap

This directory contains Terraform configuration to bootstrap the S3 backend for storing Terraform state files.

## Overview

Before you can use remote state in your environments (dev, staging, prod), you need to create the S3 buckets that will store the state files. This bootstrap configuration creates those buckets with proper security settings.

## Features

- **S3 Buckets**: One bucket per environment with versioning enabled
- **Encryption**: Server-side encryption (AES256 by default, optional KMS)
- **Public Access Blocked**: All public access is blocked
- **Versioning**: State file versioning enabled for rollback capability
- **Lifecycle Policies**: Automatic cleanup of old state versions
- **Optional DynamoDB**: Legacy state locking (not needed with S3 native locking)

## S3 Native State Locking (Recommended)

Starting with Terraform 1.9.0, S3 backends support native state locking without requiring DynamoDB. This is **OPT-IN** via the `use_lockfile=true` parameter.

### Benefits:
- No DynamoDB table required (cost savings)
- Simpler infrastructure
- Built-in locking using S3 conditional writes

### How to Enable:
1. Ensure you're using Terraform >= 1.9.0
2. In your environment's `backend.tf`, uncomment: `use_lockfile = true`
3. No DynamoDB table needed

## Prerequisites

1. **AWS Credentials**: Configure AWS credentials with appropriate permissions
   ```bash
   export AWS_PROFILE=your-profile
   # or
   export AWS_ACCESS_KEY_ID=xxx
   export AWS_SECRET_ACCESS_KEY=xxx
   ```

2. **Required IAM Permissions**:
   - `s3:CreateBucket`
   - `s3:PutBucketVersioning`
   - `s3:PutBucketEncryption`
   - `s3:PutBucketPublicAccessBlock`
   - `s3:PutLifecycleConfiguration`
   - `dynamodb:CreateTable` (only if using legacy locking)

## Usage

### Step 1: Configure Variables

Edit `terraform.tfvars` to match your configuration:

```hcl
aws_region   = "us-east-1"
project_name = "my-platform"
environments = ["dev", "staging", "prod"]

# S3 Native Locking (recommended) - no DynamoDB needed
create_dynamodb_table = false

# OR use legacy DynamoDB locking
# create_dynamodb_table = true
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

This will show you the S3 buckets (and optionally DynamoDB tables) that will be created.

### Step 4: Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### Step 5: Configure Environment Backends

After the buckets are created, configure each environment to use remote state:

1. Navigate to an environment directory:
   ```bash
   cd ../environments/aws/dev
   ```

2. Edit `backend.tf` and verify the bucket name matches

3. For S3 native locking (Terraform >= 1.9.0), uncomment:
   ```hcl
   use_lockfile = true
   ```

4. Initialize the backend:
   ```bash
   terraform init -reconfigure
   ```

5. Repeat for staging and prod environments

## State Buckets Created

The following S3 buckets will be created (using default project_name):

- `my-platform-terraform-state-dev`
- `my-platform-terraform-state-staging`
- `my-platform-terraform-state-prod`

## Security Best Practices

1. **Bucket Encryption**: All buckets have encryption at rest enabled
2. **Versioning**: Enabled for state file recovery
3. **Public Access**: Completely blocked
4. **Lifecycle Policies**: Old versions are automatically cleaned up after 90 days
5. **Access Control**: Use IAM policies to restrict access to state buckets

## Optional: KMS Encryption

To use KMS encryption instead of AES256:

1. Create a KMS key in your AWS account
2. Update `terraform.tfvars`:
   ```hcl
   enable_kms_encryption = true
   kms_key_id           = "arn:aws:kms:us-east-1:123456789012:key/xxx"
   ```

## Troubleshooting

### Bucket Already Exists
If you get an error that the bucket already exists, either:
- Use a different `project_name` in `terraform.tfvars`
- Delete the existing bucket (be careful with existing state!)
- Import the existing bucket into Terraform state

### Permission Denied
Ensure your AWS credentials have the necessary IAM permissions listed in Prerequisites.

### State Locking with DynamoDB (Legacy)

If you prefer to use DynamoDB for state locking:

1. Set `create_dynamodb_table = true` in `terraform.tfvars`
2. Apply this bootstrap configuration
3. In environment `backend.tf` files, add:
   ```hcl
   dynamodb_table = "my-platform-terraform-locks-<env>"
   ```

**Note**: DynamoDB locking is not needed if using `use_lockfile=true` (S3 native locking).

## Cleanup

To destroy the state backend infrastructure:

```bash
terraform destroy
```

**WARNING**: This will delete your state buckets. Make sure you've backed up or migrated any important state files first!

## Additional Resources

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [S3 Native State Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3#state-locking)
- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
