variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "pool_display_name" {
  description = "Display name for Workload Identity Pool"
  type        = string
  default     = "GitHub Actions Pool"
}

variable "pool_description" {
  description = "Description for Workload Identity Pool"
  type        = string
  default     = "Workload Identity Pool for GitHub Actions"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "provider_display_name" {
  description = "Display name for Workload Identity Provider"
  type        = string
  default     = "GitHub Actions Provider"
}

variable "provider_description" {
  description = "Description for Workload Identity Provider"
  type        = string
  default     = "Workload Identity Provider for GitHub Actions OIDC"
}

variable "attribute_condition" {
  description = "Attribute condition to restrict which GitHub repos can authenticate"
  type        = string
  default     = null
}

variable "create_service_account" {
  description = "Whether to create a service account for GitHub Actions"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "Service account ID for GitHub Actions"
  type        = string
  default     = "github-actions"
}

variable "service_account_display_name" {
  description = "Display name for GitHub Actions service account"
  type        = string
  default     = "GitHub Actions"
}

variable "service_account_description" {
  description = "Description for GitHub Actions service account"
  type        = string
  default     = "Service account for GitHub Actions workflows"
}

variable "allowed_repository" {
  description = "GitHub repository allowed to use this workload identity (format: owner/repo)"
  type        = string
}

variable "additional_repositories" {
  description = "Additional GitHub repositories allowed to use this workload identity (format: owner/repo)"
  type        = list(string)
  default     = []
}

variable "service_account_roles" {
  description = "List of IAM roles to grant to the service account"
  type        = list(string)
  default     = []
}
