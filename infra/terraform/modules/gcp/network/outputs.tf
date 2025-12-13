output "network_id" {
  description = "The ID of the VPC network"
  value       = module.vpc.network_id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Map of subnet information"
  value       = module.vpc.subnets
}

output "subnets_ids" {
  description = "List of subnet IDs"
  value       = module.vpc.subnets_ids
}

output "subnets_names" {
  description = "List of subnet names"
  value       = module.vpc.subnets_names
}

output "subnets_self_links" {
  description = "List of subnet self links"
  value       = module.vpc.subnets_self_links
}

output "subnets_regions" {
  description = "List of subnet regions"
  value       = module.vpc.subnets_regions
}

output "subnets_ips" {
  description = "List of subnet IP CIDR ranges"
  value       = module.vpc.subnets_ips
}

output "subnets_secondary_ranges" {
  description = "Map of subnet secondary ranges"
  value       = module.vpc.subnets_secondary_ranges
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = var.enable_nat ? google_compute_router.router[0].name : null
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = var.enable_nat ? module.cloud_nat[0].name : null
}
