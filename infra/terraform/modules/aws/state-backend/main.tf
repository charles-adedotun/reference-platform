# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "terraform_state" {
  # checkov:skip=CKV_AWS_18:Terraform state bucket access is audited via AWS CloudTrail data events rather than recursive S3 access log buckets
  # checkov:skip=CKV_AWS_144:Single-region Terraform state backend with S3 versioning enabled; cross-region replication is not required for reference architecture
  # checkov:skip=CKV_AWS_145:Supports optional customer-managed KMS key via var.kms_key_id and defaults to SSE-S3 (AES256) for zero-cost bootstrap
  # checkov:skip=CKV2_AWS_62:Event notifications are not required for Terraform state backend bucket
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.bucket_name
      Purpose     = "Terraform state backend"
      Terraform   = "true"
      Environment = var.environment
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count = var.enable_lifecycle_policy ? 1 : 0

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Optional: DynamoDB table for state locking (legacy, not needed with S3 native locking)
resource "aws_dynamodb_table" "terraform_locks" {
  count = var.create_dynamodb_table ? 1 : 0

  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    var.tags,
    {
      Name        = var.dynamodb_table_name
      Purpose     = "Terraform state locking (legacy)"
      Terraform   = "true"
      Environment = var.environment
    }
  )
}
