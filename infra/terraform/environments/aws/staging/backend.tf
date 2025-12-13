# S3 Backend Configuration with Native State Locking
#
# IMPORTANT: S3 native state locking is OPT-IN via use_lockfile=true
# This feature requires Terraform >= 1.9.0
#
# Benefits of S3 native locking:
# - No DynamoDB table required (cost savings)
# - Simpler infrastructure
# - Built-in locking mechanism using S3 conditional writes
#
# To enable S3 native locking, uncomment the use_lockfile line below.
# Note: This requires the S3 bucket to be created first (see bootstrap/ directory)

terraform {
  backend "s3" {
    bucket = "my-platform-terraform-state-staging"
    key    = "aws/staging/terraform.tfstate"
    region = "us-east-1"

    # S3 Native State Locking (OPT-IN, requires Terraform >= 1.9.0)
    # Uncomment the line below to enable native S3 locking without DynamoDB
    # use_lockfile = true

    # Legacy DynamoDB locking (optional, not needed with use_lockfile=true)
    # dynamodb_table = "terraform-state-locks"

    # Security settings
    encrypt = true

    # Additional security - consider enabling these
    # skip_credentials_validation = false
    # skip_metadata_api_check     = false
    # skip_region_validation      = false
  }
}
