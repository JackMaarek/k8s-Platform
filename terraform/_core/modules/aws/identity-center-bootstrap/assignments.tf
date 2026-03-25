# assignments.tf
# Account assignments for the bootstrap (dev) account only.
# Staging and prod assignments are managed by the identity-center-assignment module,
# called from their respective shared/ roots.

# ── platform-devs → poweruser on dev ─────────────────────────────────────────

resource "aws_ssoadmin_account_assignment" "devs_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn
  principal_id       = aws_identitystore_group.platform_devs.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"
}

# ── platform-maintainers → poweruser on dev ──────────────────────────────────

resource "aws_ssoadmin_account_assignment" "maintainers_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.poweruser_dev.arn
  principal_id       = aws_identitystore_group.platform_maintainers.group_id
  principal_type     = "GROUP"
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"
}
