variable "account_id" {
  description = "AWS account ID for this environment"
  type        = string
}

variable "sso_instance_arn" {
  description = "IAM Identity Center instance ARN — from bootstrap module outputs"
  type        = string
}

variable "permission_set_arn_readonly" {
  description = "Permission set ARN for readonly access — assigned to platform-devs"
  type        = string
}

variable "permission_set_arn_maintainers" {
  description = "Permission set ARN for platform-maintainers — varies by env (poweruser on staging, readonly on prod)"
  type        = string
}

variable "group_id_platform_devs" {
  description = "Identity store group ID for platform-devs — from bootstrap module outputs"
  type        = string
}

variable "group_id_platform_maintainers" {
  description = "Identity store group ID for platform-maintainers — from bootstrap module outputs"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
