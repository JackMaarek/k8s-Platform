# main.tf
# Responsibility: IAM Identity Center bootstrap + account assignments for all envs.
#
# This root runs in the management account (or the single account in single-account
# setups). It is the single source of truth for permission sets, groups, and
# account assignments across dev, staging, and prod.
#
# Single-account setup: dev_account_id = staging_account_id = prod_account_id.
# Multi-account setup:  each variable holds a distinct AWS account ID.
# The module logic is identical in both cases — only tfvars differ.

# ── Bootstrap — permission sets and groups ────────────────────────────────────
# Creates permission sets and Identity Center groups once.
# Idempotent — safe to apply repeatedly.

module "identity_center_bootstrap" {
  source = "../../_core/modules/aws/identity-center-bootstrap"

  cluster_name = var.cluster_name
  account_id   = var.management_account_id

  tags = {
    Component = "organization"
  }
}

# ── Dev account assignments ───────────────────────────────────────────────────
# platform-devs        → poweruser (full dev access, staging/prod denied by inline policy)
# platform-maintainers → poweruser (same permission set as devs on dev)

module "identity_center_dev" {
  source = "../../_core/modules/aws/identity-center-assignment"

  account_id                    = var.dev_account_id
  sso_instance_arn              = module.identity_center_bootstrap.sso_instance_arn
  permission_set_arn_readonly   = module.identity_center_bootstrap.permission_set_arn_readonly
  permission_set_arn_maintainers = module.identity_center_bootstrap.permission_set_arn_poweruser_dev
  group_id_platform_devs        = module.identity_center_bootstrap.group_id_platform_devs
  group_id_platform_maintainers = module.identity_center_bootstrap.group_id_platform_maintainers

  tags = {
    Environment = "dev"
    Component   = "organization"
  }
}

# ── Staging account assignments ───────────────────────────────────────────────
# platform-devs        → readonly
# platform-maintainers → platform-maintainer (poweruser with prod-deny inline policy)

module "identity_center_staging" {
  source = "../../_core/modules/aws/identity-center-assignment"

  account_id                    = var.staging_account_id
  sso_instance_arn              = module.identity_center_bootstrap.sso_instance_arn
  permission_set_arn_readonly   = module.identity_center_bootstrap.permission_set_arn_readonly
  permission_set_arn_maintainers = module.identity_center_bootstrap.permission_set_arn_platform_maintainer
  group_id_platform_devs        = module.identity_center_bootstrap.group_id_platform_devs
  group_id_platform_maintainers = module.identity_center_bootstrap.group_id_platform_maintainers

  tags = {
    Environment = "staging"
    Component   = "organization"
  }
}

# ── Prod account assignments ──────────────────────────────────────────────────
# platform-devs        → readonly
# platform-maintainers → readonly (prod apply is CI-only, no human write access)

module "identity_center_prod" {
  source = "../../_core/modules/aws/identity-center-assignment"

  account_id                    = var.prod_account_id
  sso_instance_arn              = module.identity_center_bootstrap.sso_instance_arn
  permission_set_arn_readonly   = module.identity_center_bootstrap.permission_set_arn_readonly
  permission_set_arn_maintainers = module.identity_center_bootstrap.permission_set_arn_readonly
  group_id_platform_devs        = module.identity_center_bootstrap.group_id_platform_devs
  group_id_platform_maintainers = module.identity_center_bootstrap.group_id_platform_maintainers

  tags = {
    Environment = "prod"
    Component   = "organization"
  }
}
