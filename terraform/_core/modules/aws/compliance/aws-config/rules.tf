# rules.tf
# Resource: aws_config_config_rule
#
# Managed rules that map directly to SOC2 / HIPAA controls.
# Add rules progressively — each rule has a cost implication.

locals {
  rules = {
    # Encryption at rest
    "encrypted-volumes" = {
      source     = "ENCRYPTED_VOLUMES"
      description = "SOC2 CC6.1 — EBS volumes must be encrypted"
    }
    "rds-storage-encrypted" = {
      source     = "RDS_STORAGE_ENCRYPTED"
      description = "SOC2 CC6.1 / HIPAA — RDS instances must be encrypted at rest"
    }
    "s3-bucket-ssl-requests-only" = {
      source     = "S3_BUCKET_SSL_REQUESTS_ONLY"
      description = "SOC2 CC6.7 — S3 buckets must deny HTTP requests"
    }
    # Access control
    "iam-root-access-key-check" = {
      source     = "IAM_ROOT_ACCESS_KEY_CHECK"
      description = "SOC2 CC6.2 — root account must not have active access keys"
    }
    "mfa-enabled-for-iam-console-access" = {
      source     = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
      description = "SOC2 CC6.1 — MFA required for all IAM users with console access"
    }
    "access-keys-rotated" = {
      source     = "ACCESS_KEYS_ROTATED"
      description = "SOC2 CC6.1 — IAM access keys must be rotated every 90 days"
    }
    # Network
    "vpc-flow-logs-enabled" = {
      source     = "VPC_FLOW_LOGS_ENABLED"
      description = "SOC2 CC6.6 — VPC flow logs must be enabled"
    }
    "restricted-ssh" = {
      source     = "INCOMING_SSH_DISABLED"
      description = "SOC2 CC6.6 — SSH must not be open to 0.0.0.0/0"
    }
    # Logging
    "cloud-trail-enabled" = {
      source     = "CLOUD_TRAIL_ENABLED"
      description = "SOC2 CC7.2 — CloudTrail must be enabled"
    }
    "cloudtrail-log-file-validation-enabled" = {
      source     = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
      description = "SOC2 CC7.2 / HIPAA — CloudTrail log file validation must be enabled"
    }
  }
}

resource "aws_config_config_rule" "this" {
  for_each = local.rules

  name        = each.key
  description = each.value.description

  source {
    owner             = "AWS"
    source_identifier = each.value.source
  }

  depends_on = [aws_config_configuration_recorder_status.this]

  tags = var.tags
}
