# variables.tf
# All variables in alphabetical order.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "node_groups" {
  description = <<-EOT
    Map of node groups to provision. Key = node group name suffix.
    Remove the gpu block entirely on infra without ML workloads.
    platform-bot nodegroup add generates entries here automatically.
  EOT
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    max_size       = number
    min_size       = number
    disk_size      = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}
