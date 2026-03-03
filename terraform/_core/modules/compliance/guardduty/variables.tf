variable "enabled" {
  description = "Enable GuardDuty. Recommended false in dev to reduce cost, true in staging/prod."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
