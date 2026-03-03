variable "purpose" {
  description = "What this key encrypts (e.g. secrets, s3, ebs, rds)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID — used in key policy root principal"
  type        = string
}

variable "allowed_services" {
  description = "AWS services allowed to use this key (e.g. secretsmanager.amazonaws.com)"
  type        = list(string)
  default     = []
}

variable "deletion_window_days" {
  description = "Days before key is deleted after destroy. Min 7, max 30. Use 30 in prod."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
