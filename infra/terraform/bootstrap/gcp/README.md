# GCP Terraform Bootstrap

This directory contains the bootstrap configuration for GCP Terraform infrastructure. The bootstrap process creates the initial GCS bucket for storing Terraform state files.

## Prerequisites

Before running the bootstrap:

1. **Install Required Tools**:
   - [Terraform](https://www.terraform.io/downloads) >= 1.5.0
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)

2. **GCP Project Setup**:
   ```bash
   # Create a new GCP project (or use existing)
   gcloud projects create PROJECT_ID --name="Reference Platform"

   # Set the project
   gcloud config set project PROJECT_ID

   # Enable required APIs
   gcloud services enable \
     storage.googleapis.com \
     cloudresourcemanager.googleapis.com
   ```

3. **Authentication**:
   ```bash
   # Authenticate with your Google account
   gcloud auth login

   # Set application default credentials for Terraform
   gcloud auth application-default login
   ```

## Bootstrap Process

### Step 1: Initialize Variables

Create a `terraform.tfvars` file:

```hcl
project_id  = "your-gcp-project-id"
region      = "us-central1"
bucket_name = "your-unique-bucket-name-tfstate"  # Must be globally unique
```

**Important**: The bucket name must be globally unique across all GCP projects. Consider using a naming convention like: `{company}-{project}-tfstate`

### Step 2: Run Bootstrap

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This creates:
- GCS bucket for Terraform state
- Versioning enabled (keeps 10 versions)
- Lifecycle rules for old version cleanup
- Uniform bucket-level access enabled
- Public access prevention enforced

### Step 3: Configure Environments

After the bootstrap completes:

1. **Update Backend Configuration**:

   Edit the `backend.tf` file in each environment directory:
   ```hcl
   # environments/gcp/dev/backend.tf
   terraform {
     backend "gcs" {
       bucket = "your-unique-bucket-name-tfstate"  # Use the bucket created above
       prefix = "environments/gcp/dev"
     }
   }
   ```

2. **Grant Service Account Access** (for GitHub Actions):

   After creating the Workload Identity service account:
   ```bash
   gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
     --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
     --role="roles/storage.objectAdmin"
   ```

## State Bucket Features

The created state bucket includes:

- **Versioning**: Enabled with 10 version retention
- **Lifecycle Management**: Deletes versions older than 90 days
- **Security**:
  - Uniform bucket-level access
  - Public access prevention enforced
  - Encrypted at rest by default
- **Locking**: GCS provides built-in state locking via generation numbers (no separate locking table needed)

## Directory Structure

After bootstrap, your infrastructure should look like:

```
infra/terraform/
├── bootstrap/gcp/          # Bootstrap configuration (this directory)
│   ├── main.tf
│   └── README.md
├── modules/gcp/            # Reusable modules
│   ├── network/
│   ├── gke/
│   ├── workload-identity/
│   └── state-backend/
└── environments/gcp/       # Environment configurations
    ├── dev/
    ├── staging/
    └── prod/
```

## Cleanup

To destroy the bootstrap resources (WARNING: This will delete your state bucket):

```bash
# Only do this if you want to completely tear down the infrastructure
terraform destroy
```

**Note**: You cannot destroy the bucket if it contains any objects. You'll need to empty it first or set `force_destroy = true` in the module configuration.

## Troubleshooting

### Bucket Name Already Exists

If you get an error that the bucket name already exists:
- Bucket names are globally unique across all GCP projects
- Choose a different, more unique bucket name
- Consider using a prefix like `{organization}-{project}-tfstate`

### Permission Denied

If you get permission errors:
```bash
# Verify you're authenticated
gcloud auth list

# Verify your project
gcloud config get-value project

# Ensure required APIs are enabled
gcloud services list --enabled
```

### State Locking

GCS backends use generation numbers for state locking automatically. Unlike AWS S3, you don't need a separate DynamoDB table for locking.

## Next Steps

After successful bootstrap:

1. Navigate to an environment directory (e.g., `environments/gcp/dev`)
2. Update `terraform.tfvars` with your configuration
3. Run `terraform init` to initialize the backend
4. Run `terraform plan` and `terraform apply` to create resources

See the README in each environment directory for specific instructions.
