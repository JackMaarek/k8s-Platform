# node_group.tf
# Resource: aws_eks_node_group

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  capacity_type   = var.capacity_type

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  labels = var.labels

  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, {
    Name = var.node_group_name
  })
}
