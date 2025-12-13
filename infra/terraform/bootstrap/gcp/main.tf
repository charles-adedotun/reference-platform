# GCP Bootstrap Configuration
# Creates the GCS bucket for Terraform state storage
# Run this first before deploying any environments

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the state bucket"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Terraform state (must be globally unique)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the state bucket"
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}

# Create the state bucket using the state-backend module
module "terraform_state_backend" {
  source = "../../modules/gcp/state-backend"

  project_id   = var.project_id
  bucket_name  = var.bucket_name
  location     = var.region
  storage_class = "STANDARD"

  enable_versioning = true
  force_destroy     = false

  # Lifecycle settings
  versioning_num_newer_versions = 10
  lifecycle_delete_age_days     = 90

  labels = var.labels

  # Grant access to the current user
  # You may need to add service accounts here after they're created
  bucket_admins = []

  bucket_object_admins = []

  bucket_viewers = []
}

output "bucket_name" {
  description = "Name of the created state bucket"
  value       = module.terraform_state_backend.bucket_name
}

output "bucket_url" {
  description = "URL of the state bucket"
  value       = module.terraform_state_backend.bucket_url
}

output "next_steps" {
  description = "Next steps after bootstrap"
  value       = <<-EOT
    Bootstrap complete! State bucket created: ${module.terraform_state_backend.bucket_name}

    Next steps:
    1. Update backend.tf in each environment with this bucket name:
       bucket = "${module.terraform_state_backend.bucket_name}"

    2. Initialize each environment:
       cd ../environments/gcp/dev
       terraform init
       terraform plan
       terraform apply

    3. For GitHub Actions, grant the service account access:
       gcloud storage buckets add-iam-policy-binding gs://${module.terraform_state_backend.bucket_name} \
         --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
         --role="roles/storage.objectAdmin"
  EOT
}
