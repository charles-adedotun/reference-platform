module "vpc" {
  # checkov:skip=CKV_TF_1:Using official Terraform Registry module with pinned major semantic version constraint
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS-specific subnet tags
  public_subnet_tags = merge(
    var.additional_public_subnet_tags,
    {
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )

  private_subnet_tags = merge(
    var.additional_private_subnet_tags,
    {
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )

  tags = merge(
    var.tags,
    {
      Terraform   = "true"
      Environment = var.environment
    }
  )
}
