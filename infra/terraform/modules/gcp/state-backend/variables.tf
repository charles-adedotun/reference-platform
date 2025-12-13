variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  type        = string
}

variable "location" {
  description = "Location for the GCS bucket (region or multi-region)"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Storage class for the bucket"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "Storage class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "force_destroy" {
  description = "Allow deletion of bucket even if it contains objects (use with caution)"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning for state files"
  type        = bool
  default     = true
}

variable "versioning_num_newer_versions" {
  description = "Number of newer versions to keep before deleting old versions"
  type        = number
  default     = 10
}

variable "lifecycle_delete_age_days" {
  description = "Number of days after which to delete old versions"
  type        = number
  default     = 90
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}

variable "bucket_admins" {
  description = "List of IAM members to grant storage.admin role (format: user:email, serviceAccount:email, group:email)"
  type        = list(string)
  default     = []
}

variable "bucket_object_admins" {
  description = "List of IAM members to grant storage.objectAdmin role"
  type        = list(string)
  default     = []
}

variable "bucket_viewers" {
  description = "List of IAM members to grant storage.objectViewer role"
  type        = list(string)
  default     = []
}
