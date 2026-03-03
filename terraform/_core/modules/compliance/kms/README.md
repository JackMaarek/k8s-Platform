# Module: compliance/kms

Provisions a customer-managed KMS key (CMK) with automatic annual rotation enabled.

Required for SOC2 CC6.1 and HIPAA §164.312(a)(2)(iv). AWS-managed keys are not sufficient for HIPAA — this module enforces CMK usage.

## Files

| File | Resources |
|------|-----------|
| `key.tf` | `aws_kms_key`, `aws_kms_alias` |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `purpose` | What this key encrypts (e.g. `secrets`, `s3`, `compliance`) | `string` | — | yes |
| `environment` | Environment name | `string` | — | yes |
| `account_id` | AWS account ID — used in key policy root principal | `string` | — | yes |
| `allowed_services` | AWS services allowed to use this key | `list(string)` | `[]` | no |
| `deletion_window_days` | Days before deletion after destroy. Use `30` in prod. | `number` | `30` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `key_arn` | KMS key ARN — used in resource encryption configurations |
| `key_id` | KMS key ID |
| `alias_name` | KMS key alias |
