# nodegroups.tf
# Responsibility: provision all node groups for this domain
#
# Node groups are driven entirely by var.node_groups in terraform.tfvars.
# Add, remove, or resize node groups without touching this file.
#
# To add a node group:
#   platform-bot nodegroup add --domain platform --env dev --name quantum --type c5.xlarge
#   → generates the entry in terraform.tfvars and opens a PR
#
# To remove GPU nodes on infra without ML workloads:
#   delete the "gpu" block from terraform.tfvars

module "node_groups" {
  for_each = var.node_groups

  source = "../../../_core/modules/nodegroup"

  cluster_name    = local.cluster_id
  node_group_name = "${local.cluster_id}-${each.key}"
  node_role_arn   = local.node_role_arn
  subnet_ids      = local.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  desired_size   = each.value.desired_size
  max_size       = each.value.max_size
  min_size       = each.value.min_size
  disk_size      = each.value.disk_size
  labels         = each.value.labels
  taints         = each.value.taints

  tags = {
    Environment                                           = var.environment
    NodeGroup                                             = each.key
    "k8s.io/cluster-autoscaler/enabled"                  = "true"
    "k8s.io/cluster-autoscaler/${local.cluster_id}"      = "owned"
  }
}

# ── CoreDNS addon ──────────────────────────────────────────────────────────────
# Provisioned here (after nodes) because CoreDNS requires a node to reach ACTIVE.
# Provisioning it with the cluster in _core/shared causes a timeout.

resource "aws_eks_addon" "coredns" {
  cluster_name                = local.cluster_id
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Environment = var.environment
  }

  depends_on = [module.node_groups]
}
