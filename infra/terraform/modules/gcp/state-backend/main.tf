# GCP State Backend Module
# Creates a GCS bucket for Terraform state storage with uniform access and versioning

resource "google_storage_bucket" "terraform_state" {
  project       = var.project_id
  name          = var.bucket_name
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true

  versioning {
    enabled = var.enable_versioning
  }

  lifecycle_rule {
    condition {
      num_newer_versions = var.versioning_num_newer_versions
    }
    action {
      type = "Delete"
    }
  }

  # Prevent accidental deletion of state files
  lifecycle_rule {
    condition {
      age = var.lifecycle_delete_age_days
    }
    action {
      type = "Delete"
    }
  }

  # Enable public access prevention
  public_access_prevention = "enforced"

  labels = var.labels
}

# IAM binding to allow specific service accounts or users to access the bucket
resource "google_storage_bucket_iam_member" "state_bucket_admin" {
  for_each = toset(var.bucket_admins)

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  member = each.value
}

resource "google_storage_bucket_iam_member" "state_bucket_object_admin" {
  for_each = toset(var.bucket_object_admins)

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = each.value
}

resource "google_storage_bucket_iam_member" "state_bucket_viewer" {
  for_each = toset(var.bucket_viewers)

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = each.value
}
