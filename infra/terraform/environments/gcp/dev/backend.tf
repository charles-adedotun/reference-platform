# GCS Backend Configuration for Development Environment
# GCS provides built-in state locking via generation numbers

terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"  # REPLACE with your state bucket name
    prefix = "environments/gcp/dev"
  }
}

# To initialize with a different bucket, use:
# terraform init -backend-config="bucket=your-actual-bucket-name"
