# compliance.tf
# Responsibility: compliance controls activated by compliance_profile variable
#
# Profiles:
#   none  → no controls deployed (local dev, small teams, zero cost)
#   soc2  → CloudTrail, KMS CMK, VPC Flow Logs, GuardDuty, AWS Config (~$30/month)
#   hipaa → soc2 + 6yr log retention, stricter KMS deletion window (~$50/month)
#
# Switch profile: change compliance_profile in terraform.tfvars and re-apply.
# No module refactoring required.

data "aws_caller_identity" "current" {}

locals {
  enable_compliance = var.compliance_profile != "none"
  enable_hipaa      = var.compliance_profile == "hipaa"

  # SOC2: 1 year — HIPAA §164.530(j): 6 years
  log_retention_days = local.enable_hipaa ? 2190 : 365

  # Stricter key deletion in hipaa (max window = 30 days)
  kms_deletion_window = local.enable_hipaa ? 30 : 7
}

# ── KMS customer-managed key ───────────────────────────────────────────────────
# SOC2 CC6.1 / HIPAA §164.312(a)(2)(iv)
# Required by all other compliance modules — provisioned first.

module "kms_compliance" {
  count  = local.enable_compliance ? 1 : 0
  source = "../../modules/aws/compliance/kms"

  purpose     = "compliance"
  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id

  allowed_services = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "logs.amazonaws.com",
  ]

  deletion_window_days = local.kms_deletion_window

  tags = {
    Environment = var.environment
    Compliance  = var.compliance_profile
  }
}

# ── CloudTrail ─────────────────────────────────────────────────────────────────
# SOC2 CC7.2 / HIPAA §164.312(b)

module "cloudtrail" {
  count  = local.enable_compliance ? 1 : 0
  source = "../../modules/aws/compliance/cloudtrail"

  cluster_name       = var.cluster_name
  environment        = var.environment
  kms_key_arn        = module.kms_compliance[0].key_arn
  log_retention_days = local.log_retention_days

  tags = {
    Environment = var.environment
    Compliance  = var.compliance_profile
  }
}

# ── VPC Flow Logs ──────────────────────────────────────────────────────────────
# SOC2 CC6.6 / HIPAA §164.312(b)

module "vpc_flow_logs" {
  count  = local.enable_compliance ? 1 : 0
  source = "../../modules/aws/compliance/vpc-flow-logs"

  vpc_id             = module.vpc.vpc_id
  kms_key_arn        = module.kms_compliance[0].key_arn
  log_retention_days = local.log_retention_days

  tags = {
    Environment = var.environment
    Compliance  = var.compliance_profile
  }
}

# ── GuardDuty ──────────────────────────────────────────────────────────────────
# SOC2 CC7.1 — threat detection

module "guardduty" {
  count  = local.enable_compliance ? 1 : 0
  source = "../../modules/aws/compliance/guardduty"

  enabled = true

  tags = {
    Environment = var.environment
    Compliance  = var.compliance_profile
  }
}

# ── AWS Config ─────────────────────────────────────────────────────────────────
# SOC2 CC6.1, CC7.2 — continuous compliance evaluation

module "aws_config" {
  count  = local.enable_compliance ? 1 : 0
  source = "../../modules/aws/compliance/aws-config"

  cluster_name = var.cluster_name
  environment  = var.environment
  kms_key_arn  = module.kms_compliance[0].key_arn

  tags = {
    Environment = var.environment
    Compliance  = var.compliance_profile
  }
}
