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
# apply role → env branch only (post-merge)

module "github_oidc" {
  source = "../../modules/aws/github-oidc"

  cluster_name         = var.cluster_name
  github_org           = var.github_org
  allowed_repos        = var.allowed_repos
  apply_branch_pattern = var.apply_branch_pattern
  aws_region           = var.aws_region
  state_bucket         = "k8s-platform-terraform-state-${var.aws_account_id}"
  lock_table           = "k8s-platform-terraform-locks"

  tags = {
    Environment = var.environment
    Component   = "ci-access"
  }
}
