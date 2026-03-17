# shared.tf
# Responsibility: read _core/shared outputs via remote state
# This is the single source of truth for all cross-domain references.
# Never duplicate cluster_id, subnet_ids, or node_role_arn — always read from here.

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "core/shared/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  cluster_id              = data.terraform_remote_state.shared.outputs.cluster_id
  node_role_arn           = data.terraform_remote_state.shared.outputs.node_role_arn
  private_subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_oidc_issuer_url = data.terraform_remote_state.shared.outputs.cluster_oidc_issuer_url
}
