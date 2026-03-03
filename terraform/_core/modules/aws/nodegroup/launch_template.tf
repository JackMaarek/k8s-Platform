# launch_template.tf
# Resource: aws_launch_template
# IMDSv2 enforced — prevents SSRF attacks against instance metadata

resource "aws_launch_template" "this" {
  name_prefix = "${var.node_group_name}-"
  description = "Launch template for EKS node group ${var.node_group_name}"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.node_group_name}-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.node_group_name}-volume" })
  }

  tags = var.tags
}
