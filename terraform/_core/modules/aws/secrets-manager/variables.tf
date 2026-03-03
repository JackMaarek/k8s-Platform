variable "path" {
  description = "Secret path prefix. Convention: {cluster_name}/{domain} (e.g. dev-k8s/platform)"
  type        = string
}

variable "name" {
  description = "Secret name — appended to path"
  type        = string
}

variable "domain" {
  description = "Domain that owns this secret (platform, data, quantum, qa)"
  type        = string
}

variable "description" {
  description = "Human-readable description of the secret"
  type        = string
  default     = ""
}

variable "secret_string" {
  description = "Initial secret value. Rotated outside Terraform after creation."
  type        = string
  sensitive   = true
}

variable "recovery_window_days" {
  description = "Days before permanent deletion after destroy. Use 0 for immediate deletion in dev."
  type        = number
  default     = 7
}

variable "tags" {
  description = "AWS tags applied to all resources"
  type        = map(string)
  default     = {}
}
