# Module: nodegroup

Provisions an EKS managed node group with a launch template enforcing IMDSv2, gp3 encrypted EBS, and configurable taints for workload isolation.

Supports scale-to-zero for GPU node groups (`desired_size = 0`, `min_size = 0`) — Cluster Autoscaler provisions nodes on demand when a pod with the matching toleration is pending.

This module is consumed via `for_each` on `var.node_groups` — never instantiated directly. Add or remove node groups by editing `terraform.tfvars`.

## Usage

```hcl
# nodegroups.tf — driven by terraform.tfvars
module "node_groups" {
  for_each = var.node_groups
  source   = "../../../_core/modules/nodegroup"

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
}
```

```hcl
# terraform.tfvars — the only file to edit
node_groups = {
  standard = {
    instance_types = ["t3.medium"]
    capacity_type  = "SPOT"
    desired_size   = 2
    max_size       = 4
    min_size       = 1
    disk_size      = 30
    labels         = {}
    taints         = []
  }
  # No gpu block = no GPU nodes, zero cost
}
```

## Files

| File | Resources |
|------|-----------|
| `launch_template.tf` | `aws_launch_template` |
| `node_group.tf` | `aws_eks_node_group` |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | EKS cluster name | `string` | — | yes |
| `node_group_name` | Unique node group name | `string` | — | yes |
| `node_role_arn` | Shared node IAM role ARN — from `_core/shared` outputs | `string` | — | yes |
| `subnet_ids` | Private subnet IDs for node placement | `list(string)` | — | yes |
| `instance_types` | EC2 instance types | `list(string)` | `["t3.medium"]` | no |
| `capacity_type` | `ON_DEMAND` or `SPOT` | `string` | `"SPOT"` | no |
| `desired_size` | Initial node count. Set `0` for scale-to-zero. | `number` | `2` | no |
| `max_size` | Maximum node count | `number` | `4` | no |
| `min_size` | Minimum node count. Set `0` for scale-to-zero. | `number` | `1` | no |
| `disk_size` | Root EBS volume in GiB. Use ≥ 100 for GPU nodes. | `number` | `30` | no |
| `labels` | Kubernetes labels applied to all nodes | `map(string)` | `{}` | no |
| `taints` | Kubernetes taints to isolate specialized nodes | `list(object)` | `[]` | no |
| `tags` | AWS tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `node_group_id` | EKS node group ID |
| `node_group_arn` | EKS node group ARN |
| `node_group_status` | Current node group status |
