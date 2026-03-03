# network.tf
# Responsibility: VPC, subnets, NAT gateway, routing
# All domain node groups are placed in the private subnets provisioned here.

locals {
  # Single NAT gateway in dev — saves ~$65/month per unused gateway
  # Set to false in staging and prod for AZ-level fault isolation
  single_nat_gateway = true
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.cluster_name
  cluster_name       = var.cluster_name
  cidr               = "10.0.0.0/16"
  single_nat_gateway = local.single_nat_gateway

  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]

  tags = {
    Environment = var.environment
  }
}
