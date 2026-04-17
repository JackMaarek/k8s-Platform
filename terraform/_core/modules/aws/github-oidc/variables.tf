variable "cluster_name" {
  description = "Cluster name — used as prefix for IAM role names"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name (e.g. PodYourLife)"
  type        = string
}

variable "allowed_repos" {
  description = <<-EOT
    Explicit list of GitHub repository names (without org prefix) allowed to assume
    CI roles. Zero-trust: no wildcards, no org-wide trust.
  EOT
  type        = list(string)
  validation {
    condition     = length(var.allowed_repos) > 0
    error_message = "allowed_repos must contain at least one repository name."
  }
  validation {
    condition     = !contains(var.allowed_repos, "*")
    error_message = "Wildcards are not allowed in allowed_repos."
  }
}

variable "apply_branch_pattern" {
  description = "Branch pattern allowed to trigger terraform apply. Never use bare '*'."
  type        = string
  default     = "main"
  validation {
    condition     = var.apply_branch_pattern != "*"
    error_message = "apply_branch_pattern must not be a bare wildcard."
  }
}

variable "aws_region" {
  description = "AWS region — used in IAM policy resource ARNs"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform state — scoped in apply policy"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod) — used to scope OIDC trust subjects"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID — used in IAM policy resource ARNs for DynamoDB lock table"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
