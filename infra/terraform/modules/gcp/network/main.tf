# GCP VPC Network Module
# Creates a VPC with subnets and Cloud NAT using terraform-google-modules

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = var.network_name
  routing_mode = var.routing_mode

  subnets = var.subnets

  secondary_ranges = var.secondary_ranges

  # Enable flow logs for network monitoring
  log_config = var.enable_flow_logs ? {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
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
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  count = var.enable_nat ? 1 : 0

  project_id    = var.project_id
  region        = var.nat_region
  router        = google_compute_router.router[0].name
  name          = "${var.network_name}-nat"
  create_router = false

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config = {
    enable = true
    filter = "ERRORS_ONLY"
  }
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

  source_ranges = [for subnet in var.subnets : subnet.ip_cidr_range]
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
