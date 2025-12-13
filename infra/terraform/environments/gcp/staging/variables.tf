variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "refplatform"
}

variable "region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

# Network Variables
variable "subnet_cidr" {
  description = "CIDR range for the primary subnet"
  type        = string
  default     = "10.1.0.0/24"
}

variable "pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.12.0.0/14"
}

variable "services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.16.0.0/20"
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "enable_nat" {
  description = "Enable Cloud NAT"
  type        = bool
  default     = true
}

# GKE Variables
variable "gke_regional" {
  description = "Create a regional GKE cluster"
  type        = bool
  default     = true
}

variable "gke_zones" {
  description = "Zones for GKE cluster nodes"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "gke_release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "gke_kubernetes_version" {
  description = "Kubernetes version (null for latest in release channel)"
  type        = string
  default     = null
}

variable "gke_enable_private_endpoint" {
  description = "Enable private endpoint for GKE master"
  type        = bool
  default     = false
}

variable "gke_master_cidr" {
  description = "CIDR block for GKE master"
  type        = string
  default     = "172.17.0.0/28"
}

variable "gke_master_authorized_networks" {
  description = "Networks authorized to access GKE master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "gke_node_pools" {
  description = "GKE node pools configuration"
  type = list(object({
    name               = string
    machine_type       = string
    min_count          = number
    max_count          = number
    local_ssd_count    = optional(number, 0)
    disk_size_gb       = optional(number, 100)
    disk_type          = optional(string, "pd-standard")
    image_type         = optional(string, "COS_CONTAINERD")
    auto_repair        = optional(bool, true)
    auto_upgrade       = optional(bool, true)
    preemptible        = optional(bool, false)
    initial_node_count = optional(number, 1)
  }))
  default = [
    {
      name         = "default-pool"
      machine_type = "e2-standard-2"
      min_count    = 2
      max_count    = 5
      disk_size_gb = 100
    }
  ]
}

# GitHub Actions / Workload Identity Variables
variable "github_repository" {
  description = "GitHub repository allowed to authenticate (format: owner/repo)"
  type        = string
}

variable "github_additional_repositories" {
  description = "Additional GitHub repositories allowed to authenticate"
  type        = list(string)
  default     = []
}

variable "github_attribute_condition" {
  description = "CEL expression to restrict authentication"
  type        = string
  default     = null
}

variable "github_service_account_roles" {
  description = "IAM roles for GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/container.developer",
    "roles/storage.objectViewer",
  ]
}
