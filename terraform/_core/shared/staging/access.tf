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
  github_org   = "PodYourLife"
  github_repo  = "k8s-platform"
  aws_region   = var.aws_region
  state_bucket = "k8s-platform-terraform-state"
  lock_table   = "k8s-platform-terraform-locks"

  tags = {
    Environment = var.environment
    Component   = "ci-access"
  }
}

# ── IAM Identity Center ────────────────────────────────────────────────────────
# Permission sets and group assignments for human developers.
# Users are added to groups in the AWS console (or via SCIM if Okta is connected).
#
# Groups:
#   platform-devs        → poweruser dev, readonly staging + prod
#   platform-maintainers → poweruser dev + staging, readonly prod

module "identity_center" {
  source = "../../modules/aws/identity-center"

  cluster_name       = var.cluster_name
  account_id_dev     = var.account_id_dev
  account_id_staging = var.account_id_staging
  account_id_prod    = var.account_id_prod

  tags = {
    Environment = var.environment
    Component   = "developer-access"
  }
}
