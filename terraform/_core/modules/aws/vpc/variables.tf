variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for subnet tags required by AWS Load Balancer Controller"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per availability zone"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per availability zone"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for high availability."
  }
}

variable "availability_zones" {
  description = "Availability zones — must match the count of subnet CIDR lists"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required."
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ. Recommended for non-prod to reduce cost."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
