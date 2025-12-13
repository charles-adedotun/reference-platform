output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking (if created)"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.terraform_locks[0].name : null
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking (if created)"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.terraform_locks[0].arn : null
}
