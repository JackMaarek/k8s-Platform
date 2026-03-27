# access.tf
# Responsibility: CI access via GitHub Actions OIDC.
#
# IAM Identity Center (permission sets, groups, account assignments) is managed
# in domains/organization — not here. Each env account is self-contained.
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
