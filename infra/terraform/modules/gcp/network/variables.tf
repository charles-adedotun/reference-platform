variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "routing_mode" {
  description = "The network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be REGIONAL or GLOBAL."
  }
}

variable "subnets" {
  description = "List of subnets to create in the VPC"
  type = list(object({
    subnet_name           = string
    subnet_ip             = string
    subnet_region         = string
    subnet_private_access = optional(bool, true)
    description           = optional(string, "")
  }))
}

variable "secondary_ranges" {
  description = "Secondary IP ranges for subnets (used for GKE pods and services)"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {}
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs for network monitoring"
  type        = bool
  default     = true
}

variable "enable_nat" {
  description = "Enable Cloud NAT for private instances to access internet"
  type        = bool
  default     = true
}

variable "nat_region" {
  description = "Region for Cloud NAT (should match primary subnet region)"
  type        = string
  default     = "us-central1"
}

variable "create_firewall_rules" {
  description = "Create default firewall rules for internal traffic and IAP SSH"
  type        = bool
  default     = true
}
