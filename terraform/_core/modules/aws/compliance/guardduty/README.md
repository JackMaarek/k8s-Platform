# Module: compliance/guardduty

Enables AWS GuardDuty threat detection with S3, EKS audit log, and EC2 malware scan data sources.

Controls: SOC2 CC7.1

Cost: ~$4/month per 1M events in eu-west-3. Set `enabled = false` in dev to reduce cost — controlled automatically via `compliance_profile`.

## Files

| File | Resources |
|------|-----------|
| `detector.tf` | `aws_guardduty_detector` |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `enabled` | Enable GuardDuty. Set `false` in dev. | `bool` | `true` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `detector_id` | GuardDuty detector ID |
