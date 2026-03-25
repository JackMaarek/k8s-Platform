# groups.tf
# Resources: aws_identitystore_group
#
# Groups map to permission sets per AWS account.
# Users are assigned to groups in the IdP — not managed here.
# When switching to Okta/Google, groups are pushed via SCIM provisioning
# into IAM Identity Center automatically — this file stays unchanged.

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
