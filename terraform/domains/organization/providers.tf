# providers.tf

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "k8s-platform"
      Layer     = "organization"
    }
  }
}
