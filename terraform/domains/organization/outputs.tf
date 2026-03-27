# outputs.tf
# PUBLIC API — these outputs may be consumed by future domain modules.
# Never remove or rename existing outputs without a migration plan.

output "sso_instance_arn" {
  description = "IAM Identity Center instance ARN."
  value       = module.identity_center_bootstrap.sso_instance_arn
}

output "identity_store_id" {
  description = "Identity store ID."
  value       = module.identity_center_bootstrap.identity_store_id
}

output "group_id_platform_devs" {
  description = "Identity Center group ID for platform-devs — add users via AWS console or SCIM."
  value       = module.identity_center_bootstrap.group_id_platform_devs
}

output "group_id_platform_maintainers" {
  description = "Identity Center group ID for platform-maintainers."
  value       = module.identity_center_bootstrap.group_id_platform_maintainers
}

output "permission_set_arn_readonly" {
  description = "ReadOnly permission set ARN."
  value       = module.identity_center_bootstrap.permission_set_arn_readonly
}

output "permission_set_arn_poweruser_dev" {
  description = "PowerUser dev permission set ARN."
  value       = module.identity_center_bootstrap.permission_set_arn_poweruser_dev
}

output "permission_set_arn_platform_maintainer" {
  description = "Platform maintainer permission set ARN (staging poweruser, prod deny)."
  value       = module.identity_center_bootstrap.permission_set_arn_platform_maintainer
}
