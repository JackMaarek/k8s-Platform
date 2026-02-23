terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {

    bucket         = "k8s-platform-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = "k8s-platform"
    }
  }
}

locals {
  cluster_name = "dev-k8s-cluster"
  environment  = "dev"
}

module "vpc" {
  source = "../../modules/vpc"

  environment           = local.environment
  vpc_cidr              = "10.0.0.0/16"
  private_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  availability_zones    = ["us-west-2a", "us-west-2b", "us-west-2c"]

  tags = {
    Environment = local.environment
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name         = local.cluster_name
  kubernetes_version   = "1.28"
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  public_access_cidrs  = var.public_access_cidrs

  tags = {
    Environment = local.environment
  }

  depends_on = [module.vpc]
}

module "node_group" {
  source = "../../modules/nodegroup"

  cluster_name    = local.cluster_name
  node_group_name = "${local.cluster_name}-node-group"
  subnet_ids      = module.vpc.private_subnet_ids

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  desired_size = 2
  max_size     = 4
  min_size     = 1

  disk_size = 20

  labels = {
    Environment = local.environment
    NodeGroup   = "general"
  }

  tags = {
    Environment = local.environment
  }

  depends_on = [module.eks]
}
