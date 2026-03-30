# variables.tf
# All variables are declared here in alphabetical order.

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "staging-k8s"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Restrict in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "compliance_profile" {
  description = <<-EOT
    Compliance profile to activate.
      none  → no controls deployed (local dev, small teams, zero cost)
      soc2  → CloudTrail, KMS CMK, VPC Flow Logs, GuardDuty, AWS Config (~$30/month)
      hipaa → soc2 + 6yr log retention, stricter KMS deletion window (~$50/month)
  EOT
  type        = string
  default     = "soc2"

  validation {
    condition     = contains(["none", "soc2", "hipaa"], var.compliance_profile)
    error_message = "compliance_profile must be none, soc2, or hipaa."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for EKS control plane logs."
  type        = number
  default     = 14
}

variable "github_org" {
  description = "GitHub organisation name — used by the OIDC trust policy for GitHub Actions."
  type        = string
  default     = "PodYourLife"
}

variable "allowed_repos" {
  description = "GitHub repository names (without org prefix) allowed to assume CI roles."
  type        = list(string)
}

variable "aws_account_id" {
  description = "AWS account ID for this environment — used to scope the state bucket name."
  type        = string
}
