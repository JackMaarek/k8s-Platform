# Module: compliance/cloudtrail

Provisions AWS CloudTrail with an encrypted, immutable S3 audit log bucket. Logs all management and S3 data events across all regions.

Controls: SOC2 CC7.2 / HIPAA §164.312(b)

Log retention:
- `soc2` profile → 365 days
- `hipaa` profile → 2190 days (6 years, mandated by §164.530(j))

## Files

| File | Resources |
|------|-----------|
| `trail.tf` | `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_lifecycle_configuration`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_cloudtrail` |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | Cluster name — used in bucket name | `string` | — | yes |
| `environment` | Environment name | `string` | — | yes |
| `kms_key_arn` | CMK ARN from `compliance/kms` — do not use AWS-managed keys | `string` | — | yes |
| `log_retention_days` | Retention days. SOC2: 365. HIPAA: 2190. | `number` | `365` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `trail_arn` | CloudTrail trail ARN |
| `audit_bucket_arn` | Audit log S3 bucket ARN |
| `audit_bucket_name` | Audit log S3 bucket name |
