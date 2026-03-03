variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "node_group_name" {
  description = "Unique node group name"
  type        = string
}

variable "node_role_arn" {
  description = "Shared node IAM role ARN — from _core/shared outputs"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for node placement"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT. Use SPOT for non-critical and GPU scale-to-zero workloads."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "desired_size" {
  description = "Initial number of nodes. Set to 0 for scale-to-zero GPU groups."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "min_size" {
  description = "Minimum number of nodes. Set to 0 for scale-to-zero GPU groups."
  type        = number
  default     = 1
}

variable "disk_size" {
  description = "Root EBS volume size in GiB. Use larger values for GPU nodes storing models and datasets."
  type        = number
  default     = 30
}

variable "labels" {
  description = "Kubernetes labels applied to all nodes in this group"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints to prevent unintended workloads from scheduling on specialized nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "tags" {
  description = "AWS tags applied to all resources"
  type        = map(string)
  default     = {}
}
