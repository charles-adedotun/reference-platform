# Network Outputs
output "network_name" {
  description = "Name of the VPC network"
  value       = module.network.network_name
}

output "network_id" {
  description = "ID of the VPC network"
  value       = module.network.network_id
}

output "subnet_name" {
  description = "Name of the primary subnet"
  value       = module.network.subnets_names[0]
}

output "subnet_cidr" {
  description = "CIDR range of the primary subnet"
  value       = module.network.subnets_ips[0]
}

# GKE Outputs
output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "CA certificate for the GKE cluster"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "gke_cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

output "gke_service_account" {
  description = "Service account used by GKE nodes"
  value       = module.gke.service_account
}

output "gke_master_version" {
  description = "Kubernetes version of the cluster master"
  value       = module.gke.master_version
}

# Workload Identity Outputs
output "workload_identity_pool_name" {
  description = "Workload Identity Pool name"
  value       = module.workload_identity.pool_name
}

output "workload_identity_provider_name" {
  description = "Workload Identity Provider name"
  value       = module.workload_identity.provider_name
}

output "github_actions_service_account" {
  description = "Service account email for GitHub Actions"
  value       = module.workload_identity.service_account_email
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflows"
  value       = module.workload_identity.github_actions_config
  sensitive   = true
}

# Kubectl Configuration Command
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${module.gke.cluster_location} --project ${var.project_id}"
}
