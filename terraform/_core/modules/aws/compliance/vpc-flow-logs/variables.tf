variable "vpc_id" {
  description = "VPC ID to capture traffic from"
  type        = string
}

variable "kms_key_arn" {
  description = "CMK ARN from compliance/kms"
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
