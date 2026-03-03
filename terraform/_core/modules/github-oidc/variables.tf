variable "cluster_name" {
  description = "Cluster name — used as prefix for IAM role names"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name (e.g. PodYourLife)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. k8s-platform)"
  type        = string
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

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
