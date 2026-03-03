data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = "k8s-platform-terraform-state-351457945908"
    key    = "core/shared/staging/terraform.tfstate"
    region = "eu-west-3"
  }
}

locals {
  cluster_id              = data.terraform_remote_state.shared.outputs.cluster_id
  node_role_arn           = data.terraform_remote_state.shared.outputs.node_role_arn
  private_subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_oidc_issuer_url = data.terraform_remote_state.shared.outputs.cluster_oidc_issuer_url
}
