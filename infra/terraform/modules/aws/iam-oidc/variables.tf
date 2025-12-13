variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repository identifiers allowed to assume this role (e.g., 'repo:org/repo:ref:refs/heads/main')"
  type        = list(string)
}

variable "enable_ecr_permissions" {
  description = "Enable ECR permissions for the GitHub Actions role"
  type        = bool
  default     = false
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "enable_eks_permissions" {
  description = "Enable EKS permissions for the GitHub Actions role"
  type        = bool
  default     = false
}

variable "eks_cluster_arns" {
  description = "List of EKS cluster ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "enable_s3_permissions" {
  description = "Enable S3 permissions for the GitHub Actions role"
  type        = bool
  default     = false
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "additional_policy_statements" {
  description = "Additional IAM policy statements to add to the role"
  type = list(object({
    sid       = optional(string)
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "additional_managed_policy_arns" {
  description = "List of additional managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
