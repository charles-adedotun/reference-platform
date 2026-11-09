# Bootstrap Terraform State Backend for AWS
#
# This configuration creates the S3 bucket(s) for storing Terraform state.
# Run this ONCE with local state before configuring remote backend in environments.
#
# Usage:
#   1. Update terraform.tfvars with your configuration
#   2. Run: terraform init
#   3. Run: terraform plan
#   4. Run: terraform apply
#   5. After creation, configure backend.tf in your environments to use these buckets

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  # Uses local state - DO NOT configure remote backend here
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Purpose   = "Terraform State Backend"
      ManagedBy = "Terraform"
    }
  }
}

locals {
  environments = toset(var.environments)
}

# Create S3 bucket for each environment
module "state_backend" {
  source   = "../../modules/aws/state-backend"
  for_each = local.environments

  bucket_name = "${var.project_name}-terraform-state-${each.key}"
  environment = each.key
  kms_key_id  = var.enable_kms_encryption ? var.kms_key_id : null

  enable_lifecycle_policy            = var.enable_lifecycle_policy
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days

  # DynamoDB table for legacy locking (optional)
  # Set to false if using S3 native locking (use_lockfile=true)
  create_dynamodb_table = var.create_dynamodb_table
  dynamodb_table_name   = var.create_dynamodb_table ? "${var.project_name}-terraform-locks-${each.key}" : ""

  tags = {
    Environment = each.key
  }
}
