# GCP GKE Cluster Module
# Creates a private GKE cluster using terraform-google-modules

module "gke" {
  # checkov:skip=CKV_TF_1:Using official Terraform Registry module with pinned major semantic version constraint
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 31.0"

  project_id               = var.project_id
  name                     = var.cluster_name
  region                   = var.region
  regional                 = var.regional
  zones                    = var.zones
  network                  = var.network_name
  subnetwork               = var.subnetwork_name
  ip_range_pods            = var.ip_range_pods
  ip_range_services        = var.ip_range_services
  release_channel          = var.release_channel
  kubernetes_version       = var.kubernetes_version
  remove_default_node_pool = true

  # Private cluster configuration
  enable_private_endpoint = var.enable_private_endpoint
  enable_private_nodes    = true
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block

  # Master authorized networks
  master_authorized_networks = var.master_authorized_networks

  # Horizontal Pod Autoscaling
  horizontal_pod_autoscaling = var.enable_horizontal_pod_autoscaling

  # HTTP Load Balancing
  http_load_balancing = var.enable_http_load_balancing

  # Network Policy
  network_policy = var.enable_network_policy

  # Filestore CSI driver
  filestore_csi_driver = var.enable_filestore_csi_driver

  # GKE Backup Agent
  gke_backup_agent_config = var.enable_gke_backup_agent

  # Workload Identity
  identity_namespace = "${var.project_id}.svc.id.goog"

  # Binary Authorization
  enable_binary_authorization = var.enable_binary_authorization

  # Shielded nodes
  enable_shielded_nodes = var.enable_shielded_nodes

  # Monitoring and logging
  monitoring_enable_managed_prometheus = var.enable_managed_prometheus
  logging_enabled_components           = var.logging_enabled_components
  monitoring_enabled_components        = var.monitoring_enabled_components

  # Maintenance window
  maintenance_start_time = var.maintenance_start_time

  # Resource labels
  cluster_resource_labels = var.cluster_labels

  # Node pools configuration
  node_pools = var.node_pools

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = var.node_pools_labels

  node_pools_metadata = {
    all = {
      disable-legacy-endpoints = "true"
    }
  }

  node_pools_tags = var.node_pools_tags

  node_pools_taints = var.node_pools_taints
}
