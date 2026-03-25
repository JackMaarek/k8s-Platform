# access.tf
# Responsibility: developer access (IAM Identity Center) + CI access (GitHub OIDC)
#
# IdP is currently AWS IAM Identity Center standalone (free, zero friction).
# To switch to Okta/Google/Keycloak: configure external IdP in IAM Identity Center
# console and enable SCIM provisioning — this file stays unchanged.

# ── GitHub Actions OIDC ────────────────────────────────────────────────────────
# Allows CI to assume AWS roles without storing static credentials in GitHub.
# plan role  → all branches (PR validation)
# apply role → main branch only (post-merge)

module "github_oidc" {
  source = "../../modules/aws/github-oidc"

  cluster_name = var.cluster_name
  github_org   = var.github_org
  github_repo  = var.github_repo
  aws_region   = var.aws_region
  state_bucket = "k8s-platform-terraform-state"
  lock_table   = "k8s-platform-terraform-locks"

  tags = {
    Environment = var.environment
    Component   = "ci-access"
  }
}

# ── IAM Identity Center (assignment only) ────────────────────────────────────
# Permission sets and groups are created by the bootstrap module in shared/dev.
# This module only adds prod-specific account assignments.
#
# Access matrix for prod:
#   platform-devs        → readonly
#   platform-maintainers → readonly (prod apply is CI-only)

data "terraform_remote_state" "shared_dev" {
  backend = "s3"
  config = {
    bucket = "__DEV_STATE_BUCKET__"
    key    = "core/shared/dev/terraform.tfstate"
    region = "__AWS_REGION__"
  }
}

module "identity_center_assignment" {
  source = "../../modules/aws/identity-center-assignment"

  account_id                    = var.account_id
  sso_instance_arn              = data.terraform_remote_state.shared_dev.outputs.sso_instance_arn
  permission_set_arn_readonly   = data.terraform_remote_state.shared_dev.outputs.permission_set_arn_readonly
  permission_set_arn_maintainers = data.terraform_remote_state.shared_dev.outputs.permission_set_arn_readonly
  group_id_platform_devs        = data.terraform_remote_state.shared_dev.outputs.group_id_platform_devs
  group_id_platform_maintainers = data.terraform_remote_state.shared_dev.outputs.group_id_platform_maintainers

  tags = {
    Environment = var.environment
    Component   = "developer-access"
  }
}
