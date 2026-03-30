state_bucket = "k8s-platform-terraform-state-__AWS_ACCOUNT_ID_DEV__"
aws_region   = "__AWS_REGION__"
environment  = "dev"

# Node groups — add/remove blocks to provision/destroy node groups.
# No GPU block = no GPU nodes provisioned, zero cost.
node_groups = {
  standard = {
    instance_types = ["t3.medium"]
    capacity_type  = "SPOT"
    desired_size   = 2
    max_size       = 4
    min_size       = 1
    disk_size      = 30
    labels         = { "node-group" = "standard" }
    taints         = []
  }
  gpu = {
    instance_types = ["g4dn.xlarge"]
    capacity_type  = "SPOT"
    desired_size   = 0
    max_size       = 3
    min_size       = 0
    disk_size      = 100
    labels         = { "node-group" = "gpu", "nvidia.com/gpu" = "true" }
    taints = [
      {
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]
  }
}
