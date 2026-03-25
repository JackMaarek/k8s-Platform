# assignments.tf
# Account assignments for a single non-bootstrap environment.
# Permission sets and groups are created by the identity-center-bootstrap module
# (called from shared/dev). This module only adds assignments for the local account.

# ── platform-devs → readonly on this account ─────────────────────────────────

resource "aws_ssoadmin_account_assignment" "devs" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = var.permission_set_arn_readonly
  principal_id       = var.group_id_platform_devs
  principal_type     = "GROUP"
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"
}

# ── platform-maintainers → poweruser or readonly depending on env ────────────
# Caller controls this by passing the appropriate permission_set_arn_maintainers.
# staging → platform-maintainer (poweruser with prod-deny)
# prod    → readonly

resource "aws_ssoadmin_account_assignment" "maintainers" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = var.permission_set_arn_maintainers
  principal_id       = var.group_id_platform_maintainers
  principal_type     = "GROUP"
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"
}
