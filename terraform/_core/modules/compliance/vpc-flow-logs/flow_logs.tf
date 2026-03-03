# flow_logs.tf
# Resources: aws_cloudwatch_log_group, aws_iam_role, aws_flow_log
#
# SOC2 CC6.6 — network traffic monitoring.
# HIPAA §164.312(b) — audit trail for all network access to ePHI infrastructure.
# Logs every accepted/rejected connection in the VPC.

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.vpc_id}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Compliance = "SOC2,HIPAA"
  })
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role-${var.vpc_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = var.vpc_id
  traffic_type    = "ALL" # ACCEPT + REJECT — required for compliance
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(var.tags, {
    Compliance = "SOC2,HIPAA"
  })
}
