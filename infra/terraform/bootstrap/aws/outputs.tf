output "state_bucket_ids" {
  description = "Map of environment to S3 bucket IDs for Terraform state"
  value       = { for env, backend in module.state_backend : env => backend.bucket_id }
}

output "state_bucket_arns" {
  description = "Map of environment to S3 bucket ARNs for Terraform state"
  value       = { for env, backend in module.state_backend : env => backend.bucket_arn }
}

output "state_bucket_regions" {
  description = "Map of environment to S3 bucket regions for Terraform state"
  value       = { for env, backend in module.state_backend : env => backend.bucket_region }
}

output "dynamodb_table_names" {
  description = "Map of environment to DynamoDB table names for state locking (if created)"
  value       = { for env, backend in module.state_backend : env => backend.dynamodb_table_name if backend.dynamodb_table_name != null }
}

output "next_steps" {
  description = "Instructions for next steps"
  value       = <<-EOT

    Terraform state buckets have been created successfully!

    Next steps:
    1. Update the backend.tf files in each environment directory:
       - environments/aws/dev/backend.tf
       - environments/aws/staging/backend.tf
       - environments/aws/prod/backend.tf

    2. For S3 native locking (Terraform >= 1.9.0), uncomment this line in backend.tf:
       use_lockfile = true

    3. If you created DynamoDB tables (create_dynamodb_table=true), add this line:
       dynamodb_table = "my-platform-terraform-locks-<env>"

    4. Initialize the backend in each environment:
       cd environments/aws/dev
       terraform init -reconfigure

    State bucket details:
    ${jsonencode({ for env, backend in module.state_backend : env => backend.bucket_id })}
  EOT
}
