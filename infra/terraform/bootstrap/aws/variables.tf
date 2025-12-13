variable "aws_region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environments" {
  description = "List of environments to create state buckets for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for S3 buckets"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (required if enable_kms_encryption is true)"
  type        = string
  default     = null
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy for old state versions"
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days to retain noncurrent versions of state files"
  type        = number
  default     = 90
}

variable "create_dynamodb_table" {
  description = "Create DynamoDB table for state locking (not needed if using S3 native locking with use_lockfile=true)"
  type        = bool
  default     = false
}
