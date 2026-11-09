# GCP VPC Network Module
# Creates a VPC with subnets and Cloud NAT using terraform-google-modules

module "vpc" {
  # checkov:skip=CKV_TF_1:Using official Terraform Registry module with pinned major semantic version constraint
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = var.network_name
  routing_mode = var.routing_mode

  subnets = [
    for subnet in var.subnets : merge(
      subnet,
      {
        subnet_private_access = tostring(subnet.subnet_private_access)
        subnet_flow_logs      = tostring(var.enable_flow_logs)
      },
      var.enable_flow_logs ? {
        subnet_flow_logs_interval = "INTERVAL_5_SEC"
        subnet_flow_logs_sampling = "0.5"
        subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
      } : {}
    )
  ]

  secondary_ranges = var.secondary_ranges
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  count   = var.enable_nat ? 1 : 0
  name    = "${var.network_name}-router"
  project = var.project_id
  region  = var.nat_region
  network = module.vpc.network_id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for private GKE clusters to access internet
module "cloud_nat" {
  # checkov:skip=CKV_TF_1:Using official Terraform Registry module with pinned major semantic version constraint
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  count = var.enable_nat ? 1 : 0

  project_id    = var.project_id
  region        = var.nat_region
  router        = google_compute_router.router[0].name
  name          = "${var.network_name}-nat"
  create_router = false

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config_enable = true
  log_config_filter = "ERRORS_ONLY"
}

# Firewall rules
resource "google_compute_firewall" "allow_internal" {
  count   = var.create_firewall_rules ? 1 : 0
  name    = "${var.network_name}-allow-internal"
  project = var.project_id
  network = module.vpc.network_name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [for subnet in var.subnets : subnet.subnet_ip]
  priority      = 1000
}

resource "google_compute_firewall" "allow_ssh_iap" {
  count   = var.create_firewall_rules ? 1 : 0
  name    = "${var.network_name}-allow-ssh-iap"
  project = var.project_id
  network = module.vpc.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  priority      = 1000
}
