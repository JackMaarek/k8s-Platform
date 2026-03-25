# permission_sets.tf
# Resources: aws_ssoadmin_permission_set, aws_ssoadmin_managed_policy_attachment,
#            aws_ssoadmin_permission_set_inline_policy
#
# Permission sets are IAM policy bundles assigned to users/groups per AWS account.
# They are provider-agnostic - the IdP (AWS native, Okta, Google, Keycloak) is
# configured at the Identity Center level, not here.
#
# Swap the IdP by updating the external identity provider in AWS IAM Identity Center
# console or via aws_ssoadmin_instance_access_control_attributes - no Terraform
# module change required.

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# ── ReadOnly - all environments ────────────────────────────────────────────────
# Safe for all developers: plan, describe, list. No write access.

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "${var.cluster_name}-readonly"
  description      = "Read-only access - terraform plan, describe resources. All envs."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly_view" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── PowerUser dev - dev environment only ──────────────────────────────────────
# Terraform apply on dev. Cannot touch staging or prod.

resource "aws_ssoadmin_permission_set" "poweruser_dev" {
  name             = "${var.cluster_name}-poweruser-dev"
  description      = "Full access on dev environment. No access to staging/prod."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "poweruser_dev_policy" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Deny any action on staging and prod resources from this permission set
resource "aws_ssoadmin_permission_set_inline_policy" "poweruser_dev_deny_prod" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyProdAndStagingWrite"
        Effect = "Deny"
        Action = ["*"]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = ["staging", "prod"]
          }
        }
      }
    ]
  })
}

# ── Terraform CI - assumed by GitHub Actions only ─────────────────────────────
# Applied via OIDC, not assigned to human users.
# Defined here for documentation consistency - actual role in github_oidc module.

resource "aws_ssoadmin_permission_set" "platform_maintainer" {
  name             = "${var.cluster_name}-platform-maintainer"
  description      = "Platform maintainers - staging apply, prod plan only. Prod apply via CI only."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "platform_maintainer_policy" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_maintainer.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "platform_maintainer_deny_prod_write" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_maintainer.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyProdWrite"
        Effect = "Deny"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*",
          "s3:Delete*",
          "s3:Put*",
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = ["prod"]
          }
        }
      }
    ]
  })
}
