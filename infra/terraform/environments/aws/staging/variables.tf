variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

# EKS variables
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to EKS cluster endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

# GitHub OIDC variables
variable "github_repositories" {
  description = "List of GitHub repositories allowed to assume the OIDC role"
  type        = list(string)
  default     = []
}

variable "enable_github_ecr_access" {
  description = "Enable ECR access for GitHub Actions"
  type        = bool
  default     = false
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs for GitHub Actions access"
  type        = list(string)
  default     = []
}

variable "enable_github_eks_access" {
  description = "Enable EKS access for GitHub Actions"
  type        = bool
  default     = false
}

variable "enable_github_s3_access" {
  description = "Enable S3 access for GitHub Actions"
  type        = bool
  default     = false
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for GitHub Actions access"
  type        = list(string)
  default     = []
}
