output "group_id_platform_devs" {
  description = "Identity store group ID for platform-devs"
  value       = aws_identitystore_group.platform_devs.group_id
}

output "group_id_platform_maintainers" {
  description = "Identity store group ID for platform-maintainers"
  value       = aws_identitystore_group.platform_maintainers.group_id
}

output "permission_set_arn_readonly" {
  description = "Permission set ARN for readonly access — reused by domain teams"
  value       = aws_ssoadmin_permission_set.readonly.arn
}

output "permission_set_arn_poweruser_dev" {
  description = "Permission set ARN for poweruser dev access"
  value       = aws_ssoadmin_permission_set.poweruser_dev.arn
}

output "sso_instance_arn" {
  description = "IAM Identity Center instance ARN — reused when adding domain groups"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "Identity store ID — reused when adding domain groups"
  value       = local.identity_store_id
}
