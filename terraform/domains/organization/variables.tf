# variables.tf
# All variables in alphabetical order.

variable "aws_region" {
  description = "AWS region where IAM Identity Center is active."
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "Cluster name prefix — used for permission set names."
  type        = string
}

variable "dev_account_id" {
  description = <<-EOT
    AWS account ID for the dev environment.
    In a single-account setup, set this to the same value as management_account_id.
  EOT
  type = string
}

variable "management_account_id" {
  description = <<-EOT
    AWS account ID of the management (root) account where IAM Identity Center
    is activated. In a single-account setup, this equals dev_account_id.
  EOT
  type = string
}

variable "prod_account_id" {
  description = <<-EOT
    AWS account ID for the prod environment.
    In a single-account setup, set this to the same value as management_account_id.
  EOT
  type = string
}

variable "staging_account_id" {
  description = <<-EOT
    AWS account ID for the staging environment.
    In a single-account setup, set this to the same value as management_account_id.
  EOT
  type = string
}
