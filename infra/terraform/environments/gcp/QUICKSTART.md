# GCP Terraform Quick Start

## Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] Google Cloud SDK installed
- [ ] GCP project created
- [ ] Required APIs enabled
- [ ] Authenticated with gcloud

## 5-Minute Setup

### 1. Enable Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com
```

### 2. Authenticate

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 3. Bootstrap State Backend

```bash
cd bootstrap/gcp

# Create terraform.tfvars
cat > terraform.tfvars << EOF
project_id  = "your-gcp-project-id"
region      = "us-central1"
bucket_name = "your-company-refplatform-tfstate"
EOF

terraform init
terraform apply
```

**Copy the bucket name from output!**

### 4. Deploy Dev Environment

```bash
cd ../../environments/gcp/dev

# Create terraform.tfvars
cat > terraform.tfvars << EOF
project_id        = "your-gcp-project-id"
github_repository = "your-org/your-repo"
EOF

# Update backend.tf with your bucket name
sed -i '' 's/your-terraform-state-bucket/your-company-refplatform-tfstate/g' backend.tf

terraform init
terraform plan
terraform apply
```

### 5. Connect to GKE

```bash
# Get cluster credentials
gcloud container clusters get-credentials refplatform-dev-gke \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Verify connection
kubectl get nodes
kubectl get namespaces
```

## What Gets Created

### Network Resources
- VPC network with custom subnets
- Secondary IP ranges for GKE pods/services
- Cloud NAT for internet access
- Firewall rules (internal + IAP SSH)

### GKE Cluster
- Private GKE cluster (regional by default)
- Node pool with autoscaling (1-3 nodes in dev)
- Workload Identity enabled
- Managed Prometheus monitoring
- System and workload logging

### Workload Identity
- Workload Identity Pool for GitHub Actions
- OIDC provider configured
- Service account with container.developer role

## Environment Differences

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Nodes | 1-3 | 2-5 | 3-10 |
| Instance | e2-medium | e2-standard-2 | e2-standard-4 |
| Disk | pd-standard | pd-standard | pd-ssd |
| Release | REGULAR | REGULAR | STABLE |
| Private Endpoint | No | No | Yes |
| Binary Auth | No | Yes | Yes |
| GKE Backup | No | No | Yes |

## GitHub Actions Setup

After deployment:

```bash
# Get Workload Identity configuration
terraform output github_actions_config
```

Add to `.github/workflows/deploy.yml`:

```yaml
jobs:
  deploy:
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER'
          service_account: 'SERVICE_ACCOUNT_EMAIL'

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials refplatform-dev-gke \
            --region us-central1

      - name: Deploy
        run: kubectl apply -f k8s/
```

## Common Commands

### Terraform

```bash
# Check what will change
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output

# List resources
terraform state list

# Destroy everything
terraform destroy
```

### GKE

```bash
# Get cluster info
gcloud container clusters describe CLUSTER_NAME --region REGION

# Get credentials
gcloud container clusters get-credentials CLUSTER_NAME --region REGION

# View nodes
kubectl get nodes

# View pods
kubectl get pods --all-namespaces
```

### Troubleshooting

```bash
# Check Terraform version
terraform version

# Verify authentication
gcloud auth list

# Check project
gcloud config get-value project

# List enabled APIs
gcloud services list --enabled

# View GKE cluster status
gcloud container clusters list

# Check kubectl config
kubectl config current-context
```

## Cost Estimates

### Development
- **GKE**: ~$75/month (1 e2-medium node)
- **NAT**: ~$45/month
- **Network**: ~$10/month
- **Total**: ~$130/month

### Staging
- **GKE**: ~$150/month (2 e2-standard-2 nodes)
- **NAT**: ~$45/month
- **Network**: ~$10/month
- **Total**: ~$205/month

### Production
- **GKE**: ~$450/month (3 e2-standard-4 nodes + SSD)
- **NAT**: ~$45/month
- **Network**: ~$15/month
- **Backup**: ~$10/month
- **Total**: ~$520/month

*Estimates based on us-central1 pricing. Actual costs vary with usage.*

## Next Steps

1. **Configure Monitoring**:
   - Set up alerts in Cloud Monitoring
   - Configure log-based metrics
   - Enable uptime checks

2. **Deploy Applications**:
   - Create Kubernetes namespaces
   - Deploy workloads via kubectl or GitHub Actions
   - Configure ingress/load balancers

3. **Enhance Security**:
   - Configure Binary Authorization policies
   - Set up VPN for private endpoint access
   - Enable Security Command Center

4. **Staging/Prod**:
   - Repeat steps for staging environment
   - Configure production with private endpoint
   - Set up backup schedules

## Support

- **Documentation**: See [README.md](README.md) for detailed information
- **Bootstrap Guide**: [../../bootstrap/gcp/README.md](../../bootstrap/gcp/README.md)
- **GCP Console**: https://console.cloud.google.com
- **Terraform Registry**: https://registry.terraform.io/providers/hashicorp/google/latest

## Clean Up

To delete everything:

```bash
# Destroy environment
cd environments/gcp/dev
terraform destroy

# Destroy bootstrap (WARNING: Deletes state bucket!)
cd ../../bootstrap/gcp
terraform destroy
```

**Warning**: This permanently deletes all resources. Export any important data first!
