output "bucket_name" {
  description = "Name of the state bucket"
  value       = google_storage_bucket.terraform_state.name
}

output "bucket_url" {
  description = "URL of the state bucket"
  value       = google_storage_bucket.terraform_state.url
}

output "bucket_self_link" {
  description = "Self link of the state bucket"
  value       = google_storage_bucket.terraform_state.self_link
}

output "bucket_location" {
  description = "Location of the state bucket"
  value       = google_storage_bucket.terraform_state.location
}

output "backend_config" {
  description = "Backend configuration block for use in terraform backend configuration"
  value = {
    bucket = google_storage_bucket.terraform_state.name
    prefix = "terraform/state"
  }
}
