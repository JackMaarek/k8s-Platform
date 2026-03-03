# key.tf
# Resource: aws_kms_key, aws_kms_alias
#
# Customer-managed KMS keys — required for HIPAA, recommended for SOC2.
# Each domain gets its own key for blast radius isolation.
# Key rotation is enabled by default (mandatory for compliance).

resource "aws_kms_key" "this" {
  description             = "CMK for ${var.purpose} — ${var.environment}"
  deletion_window_in_days = var.deletion_window_days
  enable_key_rotation     = true # mandatory for SOC2/HIPAA

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = var.allowed_services
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose     = var.purpose
    Environment = var.environment
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.environment}/${var.purpose}"
  target_key_id = aws_kms_key.this.key_id
}
