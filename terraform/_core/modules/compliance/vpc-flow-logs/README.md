# Module: compliance/vpc-flow-logs

Captures all accepted and rejected VPC network traffic to CloudWatch Logs, encrypted with a CMK.

Controls: SOC2 CC6.6 / HIPAA §164.312(b)

## Files

| File | Resources |
|------|-----------|
| `flow_logs.tf` | `aws_cloudwatch_log_group`, `aws_iam_role`, `aws_iam_role_policy`, `aws_flow_log` |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_id` | VPC ID to capture traffic from | `string` | — | yes |
| `kms_key_arn` | CMK ARN from `compliance/kms` | `string` | — | yes |
| `log_retention_days` | Retention days. SOC2: 365. HIPAA: 2190. | `number` | `365` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `flow_log_id` | VPC flow log ID |
| `log_group_name` | CloudWatch log group name |
