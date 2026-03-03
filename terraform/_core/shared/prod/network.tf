# network.tf
# Multi-AZ NAT gateways in prod for fault isolation

locals {
  single_nat_gateway = false
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.cluster_name
  cluster_name       = var.cluster_name
  cidr               = "10.1.0.0/16"
  single_nat_gateway = local.single_nat_gateway

  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]

  tags = {
    Environment = var.environment
  }
}
