# GCP Production Environment
# Root module that orchestrates all GCP infrastructure components

locals {
  environment = "prod"
  region      = var.region
  project_id  = var.project_id

  common_labels = {
    environment = local.environment
    managed_by  = "terraform"
    project     = "reference-platform"
  }
}

# Network Module
module "network" {
  source = "../../../modules/gcp/network"

  project_id   = local.project_id
  network_name = "${var.project_name}-${local.environment}-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${var.project_name}-${local.environment}-subnet"
      subnet_ip             = var.subnet_cidr
      subnet_region         = local.region
      subnet_private_access = true
      description           = "Primary subnet for ${local.environment} environment"
    }
  ]

  secondary_ranges = {
    "${var.project_name}-${local.environment}-subnet" = [
      {
        range_name    = "pods"
        ip_cidr_range = var.pods_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = var.services_cidr
      }
    ]
  }

  enable_flow_logs        = var.enable_flow_logs
  enable_nat              = var.enable_nat
  nat_region              = local.region
  create_firewall_rules   = true
}

# GKE Cluster Module
module "gke" {
  source = "../../../modules/gcp/gke"

  project_id      = local.project_id
  cluster_name    = "${var.project_name}-${local.environment}-gke"
  region          = local.region
  regional        = var.gke_regional
  zones           = var.gke_zones
  network_name    = module.network.network_name
  subnetwork_name = module.network.subnets_names[0]
  ip_range_pods   = "pods"
  ip_range_services = "services"

  release_channel         = var.gke_release_channel
  kubernetes_version      = var.gke_kubernetes_version
  enable_private_endpoint = var.gke_enable_private_endpoint
  master_ipv4_cidr_block  = var.gke_master_cidr

  master_authorized_networks = var.gke_master_authorized_networks

  enable_horizontal_pod_autoscaling = true
  enable_http_load_balancing        = true
  enable_network_policy             = true
  enable_binary_authorization       = true
  enable_shielded_nodes             = true
  enable_managed_prometheus         = true
  enable_gke_backup_agent           = true

  logging_enabled_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  monitoring_enabled_components = ["SYSTEM_COMPONENTS"]

  maintenance_start_time = "03:00"

  cluster_labels = merge(
    local.common_labels,
    {
      cluster     = "${var.project_name}-${local.environment}-gke"
      criticality = "high"
    }
  )

  node_pools = var.gke_node_pools

  node_pools_labels = {
    all = merge(
      local.common_labels,
      {
        node_pool = "default"
      }
    )
  }

  node_pools_tags = {
    all = [
      "${local.environment}-gke-node",
      "gke-node"
    ]
  }

  depends_on = [module.network]
}

# Workload Identity Module
module "workload_identity" {
  source = "../../../modules/gcp/workload-identity"

  project_id = local.project_id

  pool_id           = "${var.project_name}-${local.environment}-github-pool"
  pool_display_name = "GitHub Actions Pool - ${upper(local.environment)}"
  pool_description  = "Workload Identity Pool for GitHub Actions in ${local.environment}"

  provider_id           = "github-provider"
  provider_display_name = "GitHub Actions Provider"
  provider_description  = "OIDC provider for GitHub Actions"

  attribute_condition = var.github_attribute_condition

  create_service_account        = true
  service_account_id            = "${var.project_name}-${local.environment}-github-actions"
  service_account_display_name  = "GitHub Actions - ${upper(local.environment)}"
  service_account_description   = "Service account for GitHub Actions in ${local.environment}"

  allowed_repository      = var.github_repository
  additional_repositories = var.github_additional_repositories

  service_account_roles = var.github_service_account_roles
}
