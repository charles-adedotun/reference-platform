# GCP Workload Identity Federation Module
# Sets up Workload Identity Federation for GitHub Actions

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = var.pool_description
  disabled                  = false
}

# Workload Identity Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_display_name
  description                        = var.provider_description
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = var.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service Account for GitHub Actions
resource "google_service_account" "github_actions" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
  description  = var.service_account_description
}

# Allow GitHub Actions to impersonate the service account
resource "google_service_account_iam_member" "workload_identity_user" {
  count              = var.create_service_account ? 1 : 0
  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.allowed_repository}"
}

# Project-level IAM bindings for the service account
resource "google_project_iam_member" "service_account_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# Additional repository mappings
resource "google_service_account_iam_member" "additional_repositories" {
  for_each = var.create_service_account ? toset(var.additional_repositories) : []

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value}"
}
