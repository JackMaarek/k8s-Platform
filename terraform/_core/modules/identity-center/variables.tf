variable "cluster_name" {
  description = "Cluster name — used as prefix for permission set names"
  type        = string
}

variable "account_id_dev" {
  description = "AWS account ID for the dev environment"
  type        = string
}

variable "account_id_staging" {
  description = "AWS account ID for the staging environment"
  type        = string
}

variable "account_id_prod" {
  description = "AWS account ID for the prod environment"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
