# group_assignments.tf
# Resources: aws_identitystore_group, aws_ssoadmin_account_assignment
#
# Groups map to permission sets per AWS account.
# Users are assigned to groups in the IdP — not managed here.
# When switching to Okta/Google, groups are pushed via SCIM provisioning
# into IAM Identity Center automatically — this file stays unchanged.

# ── Groups ─────────────────────────────────────────────────────────────────────

resource "aws_identitystore_group" "platform_devs" {
  identity_store_id = local.identity_store_id
  display_name      = "platform-devs"
  description       = "Platform team developers — dev poweruser, staging/prod readonly"
}

resource "aws_identitystore_group" "platform_maintainers" {
  identity_store_id = local.identity_store_id
  display_name      = "platform-maintainers"
  description       = "Platform team maintainers — dev/staging poweruser, prod readonly + plan"
}

# ── Account assignments ────────────────────────────────────────────────────────
# platform-devs → poweruser on dev, readonly on staging + prod

resource "aws_ssoadmin_account_assignment" "devs_dev_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn
  principal_id       = aws_identitystore_group.platform_devs.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_dev
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "devs_staging_readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  principal_id       = aws_identitystore_group.platform_devs.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_staging
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "devs_prod_readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  principal_id       = aws_identitystore_group.platform_devs.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_prod
  target_type        = "AWS_ACCOUNT"
}

# platform-maintainers → poweruser on dev + staging, readonly on prod

resource "aws_ssoadmin_account_assignment" "maintainers_dev_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn
  principal_id       = aws_identitystore_group.platform_maintainers.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_dev
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "maintainers_staging_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_maintainer.arn
  principal_id       = aws_identitystore_group.platform_maintainers.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_staging
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "maintainers_prod_readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  principal_id       = aws_identitystore_group.platform_maintainers.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id_prod
  target_type        = "AWS_ACCOUNT"
}
