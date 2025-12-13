output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = module.gke.cluster_id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location (region or zone) of the GKE cluster"
  value       = module.gke.location
}

output "cluster_region" {
  description = "The region of the GKE cluster"
  value       = module.gke.region
}

output "cluster_zones" {
  description = "The zones of the GKE cluster"
  value       = module.gke.zones
}

output "master_version" {
  description = "The current version of the master in the cluster"
  value       = module.gke.master_version
}

output "service_account" {
  description = "The default service account used for running nodes"
  value       = module.gke.service_account
}

output "identity_namespace" {
  description = "Workload Identity namespace"
  value       = module.gke.identity_namespace
}

output "network_policy_enabled" {
  description = "Whether network policy is enabled on the cluster"
  value       = module.gke.network_policy_enabled
}

output "horizontal_pod_autoscaling_enabled" {
  description = "Whether horizontal pod autoscaling is enabled"
  value       = module.gke.horizontal_pod_autoscaling_enabled
}

output "http_load_balancing_enabled" {
  description = "Whether HTTP load balancing is enabled"
  value       = module.gke.http_load_balancing_enabled
}

output "master_authorized_networks_config" {
  description = "Networks from which access to master is permitted"
  value       = module.gke.master_authorized_networks_config
}

output "min_master_version" {
  description = "The minimum version of the master"
  value       = module.gke.min_master_version
}

output "logging_service" {
  description = "Logging service used"
  value       = module.gke.logging_service
}

output "monitoring_service" {
  description = "Monitoring service used"
  value       = module.gke.monitoring_service
}

output "node_pools_names" {
  description = "List of node pool names"
  value       = module.gke.node_pools_names
}

output "node_pools_versions" {
  description = "Node pool versions by node pool name"
  value       = module.gke.node_pools_versions
}
