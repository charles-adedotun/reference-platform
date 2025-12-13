output "pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "pool_name" {
  description = "Workload Identity Pool name"
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_id" {
  description = "Workload Identity Provider ID"
  value       = google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id
}

output "provider_name" {
  description = "Workload Identity Provider name"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Email of the service account created for GitHub Actions"
  value       = var.create_service_account ? google_service_account.github_actions[0].email : null
}

output "service_account_name" {
  description = "Name of the service account created for GitHub Actions"
  value       = var.create_service_account ? google_service_account.github_actions[0].name : null
}

output "service_account_id" {
  description = "ID of the service account created for GitHub Actions"
  value       = var.create_service_account ? google_service_account.github_actions[0].id : null
}

output "workload_identity_provider" {
  description = "Full workload identity provider resource name for use in GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_actions_config" {
  description = "Configuration values for GitHub Actions workflow"
  value = var.create_service_account ? {
    workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
    service_account           = google_service_account.github_actions[0].email
    project_id                = var.project_id
  } : null
}
