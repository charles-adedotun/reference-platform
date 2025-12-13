variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The region for the GKE cluster"
  type        = string
}

variable "regional" {
  description = "Whether to create a regional cluster (true) or zonal cluster (false)"
  type        = bool
  default     = true
}

variable "zones" {
  description = "The zones for the GKE cluster (for zonal or regional clusters)"
  type        = list(string)
  default     = []
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnetwork_name" {
  description = "The name of the subnet"
  type        = string
}

variable "ip_range_pods" {
  description = "The secondary IP range name for pods"
  type        = string
}

variable "ip_range_services" {
  description = "The secondary IP range name for services"
  type        = string
}

variable "release_channel" {
  description = "The release channel for the GKE cluster (RAPID, REGULAR, STABLE, or UNSPECIFIED)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, STABLE, or UNSPECIFIED."
  }
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the master. If not specified, the latest version in the release channel is used."
  type        = string
  default     = null
}

variable "enable_private_endpoint" {
  description = "Whether the master's internal IP address is used as the cluster endpoint"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the hosted master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of master authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Enable Horizontal Pod Autoscaling addon"
  type        = bool
  default     = true
}

variable "enable_http_load_balancing" {
  description = "Enable HTTP Load Balancing addon"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable network policy addon"
  type        = bool
  default     = true
}

variable "enable_filestore_csi_driver" {
  description = "Enable Filestore CSI driver"
  type        = bool
  default     = false
}

variable "enable_gke_backup_agent" {
  description = "Enable GKE Backup Agent"
  type        = bool
  default     = false
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for this cluster"
  type        = bool
  default     = false
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded Nodes features on all nodes in this cluster"
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = true
}

variable "logging_enabled_components" {
  description = "List of GKE components for which to enable logging"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_enabled_components" {
  description = "List of GKE components for which to enable monitoring"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "maintenance_start_time" {
  description = "Time window for maintenance (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "cluster_labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "node_pools" {
  description = "List of node pools to create"
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
      machine_type = "e2-medium"
      min_count    = 1
      max_count    = 3
    }
  ]
}

variable "node_pools_labels" {
  description = "Map of maps containing node labels by node pool"
  type        = map(map(string))
  default = {
    all = {}
  }
}

variable "node_pools_tags" {
  description = "Map of lists containing node tags by node pool"
  type        = map(list(string))
  default = {
    all = []
  }
}

variable "node_pools_taints" {
  description = "Map of lists containing node taints by node pool"
  type        = map(list(object({
    key    = string
    value  = string
    effect = string
  })))
  default = {
    all = []
  }
}
