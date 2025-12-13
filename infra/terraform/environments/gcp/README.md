# GCP Terraform Environments

This directory contains Terraform configurations for deploying infrastructure on Google Cloud Platform (GCP) across multiple environments.

## Overview

The GCP infrastructure includes:
- **VPC Network** with subnets and Cloud NAT
- **GKE (Google Kubernetes Engine)** private cluster
- **Workload Identity Federation** for GitHub Actions
- **GCS Backend** for Terraform state storage

## Architecture

```
GCP Project
├── VPC Network
│   ├── Subnet (with secondary ranges for GKE)
│   ├── Cloud Router
│   ├── Cloud NAT
│   └── Firewall Rules
├── GKE Cluster
│   ├── Private cluster with Workload Identity
│   ├── Node pools with autoscaling
│   ├── Managed Prometheus monitoring
│   └── Binary Authorization (staging/prod)
└── Workload Identity
    ├── Workload Identity Pool
    ├── OIDC Provider (GitHub)
    └── Service Account for GitHub Actions
```

## Environments

### Development (`dev/`)
- **Purpose**: Development and testing
- **GKE**: 1-3 nodes, e2-medium instances
- **Release Channel**: REGULAR
- **Private Endpoint**: Disabled
- **Network**: 10.0.0.0/24

### Staging (`staging/`)
- **Purpose**: Pre-production testing
- **GKE**: 2-5 nodes, e2-standard-2 instances
- **Release Channel**: REGULAR
- **Private Endpoint**: Disabled
- **Binary Authorization**: Enabled
- **Network**: 10.1.0.0/24

### Production (`prod/`)
- **Purpose**: Production workloads
- **GKE**: 3-10 nodes, e2-standard-4 instances, SSD disks
- **Release Channel**: STABLE
- **Private Endpoint**: Enabled (requires bastion/VPN)
- **Binary Authorization**: Enabled
- **GKE Backup**: Enabled
- **Network**: 10.2.0.0/24

## Prerequisites

1. **Tools**:
   - Terraform >= 1.5.0
   - Google Cloud SDK
   - kubectl

2. **GCP Setup**:
   ```bash
   # Set project
   gcloud config set project YOUR_PROJECT_ID

   # Enable required APIs
   gcloud services enable \
     compute.googleapis.com \
     container.googleapis.com \
     iam.googleapis.com \
     cloudresourcemanager.googleapis.com \
     storage.googleapis.com
   ```

3. **Authentication**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

## Getting Started

### 1. Bootstrap State Backend

First, create the GCS bucket for Terraform state:

```bash
cd ../../bootstrap/gcp
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform apply
```

### 2. Update Backend Configuration

Update `backend.tf` in each environment with your state bucket name.

### 3. Deploy an Environment

```bash
cd ../environments/gcp/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

terraform init
terraform plan
terraform apply
```

## Configuration

### Required Variables

Each environment requires these variables in `terraform.tfvars`:

```hcl
# GCP Project
project_id = "your-gcp-project-id"
region     = "us-central1"

# GitHub Actions
github_repository = "your-org/your-repo"

# Network (adjust per environment)
subnet_cidr    = "10.0.0.0/24"
pods_cidr      = "10.4.0.0/14"
services_cidr  = "10.8.0.0/20"
```

### Optional Variables

```hcl
# GKE Configuration
gke_zones = ["us-central1-a", "us-central1-b", "us-central1-c"]
gke_release_channel = "REGULAR"

# Master Authorized Networks
gke_master_authorized_networks = [
  {
    cidr_block   = "203.0.113.0/24"
    display_name = "Office Network"
  }
]

# Node Pools
gke_node_pools = [
  {
    name         = "default-pool"
    machine_type = "e2-medium"
    min_count    = 1
    max_count    = 3
  }
]
```

## Accessing GKE Clusters

### Public Endpoint (dev/staging)

```bash
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID

kubectl get nodes
```

### Private Endpoint (prod)

For production with private endpoint enabled, you need:
1. A bastion host in the VPC, or
2. VPN connection to the VPC, or
3. Cloud Shell (already in Google's network)

```bash
# From bastion or Cloud Shell
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID \
  --internal-ip

kubectl get nodes
```

## GitHub Actions Integration

After deploying Workload Identity:

1. **Get the configuration**:
   ```bash
   terraform output github_actions_config
   ```

2. **Update your GitHub workflow**:
   ```yaml
   jobs:
     deploy:
       permissions:
         id-token: write
         contents: read
       steps:
         - uses: google-github-actions/auth@v2
           with:
             workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID'
             service_account: 'SERVICE_ACCOUNT_EMAIL'

         - name: Configure kubectl
           run: |
             gcloud container clusters get-credentials CLUSTER_NAME \
               --region REGION \
               --project PROJECT_ID
   ```

## Modules Used

### Official Google Modules

- **terraform-google-modules/network/google** (~> 9.0)
  - VPC network with subnets
  - Secondary IP ranges for GKE

- **terraform-google-modules/cloud-nat/google** (~> 5.0)
  - Cloud NAT for private GKE nodes

- **terraform-google-modules/kubernetes-engine/google** (~> 31.0)
  - Private GKE cluster
  - Node pools with autoscaling
  - Workload Identity enabled

### Custom Modules

- **modules/gcp/network**: VPC, subnets, NAT, firewall rules
- **modules/gcp/gke**: GKE cluster configuration
- **modules/gcp/workload-identity**: GitHub Actions OIDC integration
- **modules/gcp/state-backend**: GCS bucket for state storage

## State Management

### Backend Configuration

GCS backend with built-in locking:

```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "environments/gcp/dev"
  }
}
```

### State Locking

GCS provides automatic state locking via generation numbers. No additional configuration needed.

### State Inspection

```bash
# List state resources
terraform state list

# Show specific resource
terraform state show module.gke.module.gke.google_container_cluster.primary

# Pull remote state
terraform state pull > terraform.tfstate.backup
```

## Network Architecture

### IP Addressing

| Environment | Subnet      | Pods         | Services    | Master     |
|-------------|-------------|--------------|-------------|------------|
| Dev         | 10.0.0.0/24 | 10.4.0.0/14  | 10.8.0.0/20 | 172.16.0.0/28 |
| Staging     | 10.1.0.0/24 | 10.12.0.0/14 | 10.16.0.0/20| 172.17.0.0/28 |
| Prod        | 10.2.0.0/24 | 10.20.0.0/14 | 10.24.0.0/20| 172.18.0.0/28 |

### Firewall Rules

Automatically created:
- Internal communication between subnets
- SSH access via Identity-Aware Proxy (IAP)
- GKE control plane to nodes communication

## Cost Optimization

### Development
- Preemptible nodes option available
- Smaller instance types (e2-medium)
- Min 1 node with autoscaling

### Staging
- Standard instances for stability
- Moderate sizing (e2-standard-2)
- Min 2 nodes for HA testing

### Production
- Non-preemptible instances
- SSD persistent disks
- Higher node counts for availability
- GKE Backup enabled for disaster recovery

## Monitoring and Logging

All environments include:
- **Cloud Logging**: SYSTEM_COMPONENTS and WORKLOADS
- **Cloud Monitoring**: SYSTEM_COMPONENTS
- **Managed Prometheus**: Enabled for metrics collection
- **VPC Flow Logs**: Network traffic monitoring

Access logs via:
```bash
# GKE logs
gcloud logging read "resource.type=k8s_cluster"

# Pod logs
kubectl logs POD_NAME

# Cloud Console
# https://console.cloud.google.com/logs
```

## Troubleshooting

### Common Issues

**Cannot connect to GKE cluster**:
- Verify your IP is in master_authorized_networks
- For private endpoint, ensure you're on bastion/VPN
- Check credentials: `gcloud auth list`

**Terraform state locked**:
- GCS automatically releases locks after timeout
- Check for stuck processes: `ps aux | grep terraform`

**Module version conflicts**:
- Run `terraform init -upgrade`
- Check provider version constraints

**API not enabled**:
```bash
gcloud services list --available
gcloud services enable SERVICE_NAME
```

## Clean Up

To destroy an environment:

```bash
cd environments/gcp/dev
terraform destroy
```

**Warning**: This will delete all resources including the GKE cluster and VPC.

## Security Best Practices

1. **Enable Binary Authorization** (staging/prod)
2. **Use Private GKE Endpoint** (prod)
3. **Restrict Master Authorized Networks**
4. **Enable Shielded Nodes**
5. **Use Workload Identity** instead of service account keys
6. **Enable VPC Flow Logs** for audit trail
7. **Rotate node pools** regularly for security patches

## Additional Resources

- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [VPC Network Design](https://cloud.google.com/vpc/docs/vpc)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
