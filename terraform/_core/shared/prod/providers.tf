# providers.tf

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = "k8s-platform"
      Layer       = "core-shared"
    }
  }
}
