locals {
  environment  = "prod"
  cluster_name = "${var.project_name}-${local.environment}"
  region       = var.aws_region

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# Network module
module "network" {
  source = "../../../modules/aws/network"

  vpc_name             = "${var.project_name}-${local.environment}"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  cluster_name         = local.cluster_name
  environment          = local.environment

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = local.common_tags
}

# EKS module
module "eks" {
  source = "../../../modules/aws/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  managed_node_groups = {
    default = {
      name = "default-${local.environment}"

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = 100

      labels = {
        Environment = local.environment
        NodeGroup   = "default"
      }

      tags = {
        NodeGroup = "default-${local.environment}"
      }
    }
  }

  environment = local.environment
  tags        = local.common_tags
}

# IAM OIDC for GitHub Actions
module "github_oidc" {
  source = "../../../modules/aws/iam-oidc"

  name_prefix         = "${var.project_name}-${local.environment}"
  environment         = local.environment
  github_repositories = var.github_repositories

  enable_ecr_permissions = var.enable_github_ecr_access
  ecr_repository_arns    = var.ecr_repository_arns

  enable_eks_permissions = var.enable_github_eks_access
  eks_cluster_arns       = var.enable_github_eks_access ? [module.eks.cluster_arn] : []

  enable_s3_permissions = var.enable_github_s3_access
  s3_bucket_arns        = var.s3_bucket_arns

  tags = local.common_tags
}
