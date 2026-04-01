state_bucket = "k8s-platform-terraform-state-__AWS_ACCOUNT_ID_PROD__"
aws_region   = "__AWS_REGION__"
environment  = "prod"

node_groups = {
  standard = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 3
    max_size       = 10
    min_size       = 2
    disk_size      = 50
    labels         = { "node-group" = "standard" }
    taints         = []
  }
  # gpu = {
  #   instance_types = ["g4dn.xlarge"]
  #   capacity_type  = "SPOT"
  #   desired_size   = 0
  #   max_size       = 5
  #   min_size       = 0
  #   disk_size      = 100
  #   labels         = { "node-group" = "gpu", "nvidia.com/gpu" = "true" }
  #   taints = [
  #     {
  #       key    = "nvidia.com/gpu"
  #       value  = "true"
  #       effect = "NO_SCHEDULE"
  #     }
  #   ]
  # }
}
