variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL from the EKS cluster — from _core/shared outputs"
  type        = string
}

variable "role_name" {
  description = "IAM role name. Convention: {cluster_name}-{service}-role (e.g. dev-k8s-eso-role)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name that will assume this role"
  type        = string
}

variable "policy_statements" {
  description = "IAM policy statements granting AWS permissions to the service account"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "tags" {
  description = "AWS tags applied to all resources"
  type        = map(string)
  default     = {}
}
