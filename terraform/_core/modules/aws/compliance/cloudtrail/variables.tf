variable "cluster_name" {
  description = "Cluster name — used in bucket name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "CMK ARN from compliance/kms — do not use AWS-managed keys"
  type        = string
}

variable "log_retention_days" {
  description = "Retention days. SOC2: 365. HIPAA: 2190."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
