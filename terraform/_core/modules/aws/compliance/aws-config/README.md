# Module: compliance/aws-config

Enables AWS Config continuous recording with an encrypted S3 delivery channel and 10 managed compliance rules mapped to SOC2/HIPAA controls.

Controls: SOC2 CC6.1, CC7.2

Cost: ~$0.003 per rule evaluation. Disabled in dev via `compliance_profile = "none"`.

## Managed rules

| Rule | Control |
|------|---------|
| `encrypted-volumes` | SOC2 CC6.1 — EBS volumes encrypted |
| `rds-storage-encrypted` | SOC2 CC6.1 / HIPAA — RDS encrypted at rest |
| `s3-bucket-ssl-requests-only` | SOC2 CC6.7 — S3 deny HTTP |
| `iam-root-access-key-check` | SOC2 CC6.2 — no root access keys |
| `mfa-enabled-for-iam-console-access` | SOC2 CC6.1 — MFA required |
| `access-keys-rotated` | SOC2 CC6.1 — keys rotated every 90 days |
| `vpc-flow-logs-enabled` | SOC2 CC6.6 — VPC flow logs on |
| `restricted-ssh` | SOC2 CC6.6 — no SSH open to 0.0.0.0/0 |
| `cloud-trail-enabled` | SOC2 CC7.2 — CloudTrail on |
| `cloudtrail-log-file-validation-enabled` | SOC2 CC7.2 / HIPAA — tamper detection |

## Files

| File | Resources |
|------|-----------|
| `recorder.tf` | `aws_s3_bucket`, encryption + lifecycle + policy, `aws_iam_role`, `aws_config_configuration_recorder`, `aws_config_delivery_channel`, `aws_config_configuration_recorder_status` |
| `rules.tf` | `aws_config_config_rule` × 10 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | Cluster name — used in resource names | `string` | — | yes |
| `environment` | Environment name | `string` | — | yes |
| `kms_key_arn` | CMK ARN from `compliance/kms` | `string` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `recorder_name` | AWS Config recorder name |
| `config_bucket` | Config snapshots S3 bucket |
| `rules_enabled` | List of active rule names |
