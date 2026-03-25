variable "cluster_name" {
  description = "Cluster name — used as prefix for permission set names"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for this environment (bootstrap account)"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
