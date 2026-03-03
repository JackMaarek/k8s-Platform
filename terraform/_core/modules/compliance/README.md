# _core/modules/compliance

Compliance control modules activated via the `compliance_profile` variable. Designed to be progressively enabled as the team's compliance requirements grow.

## Profiles

| Profile | Modules active | Cost (eu-west-3) | Use case |
|---------|---------------|-------------------|----------|
| `none` | — | $0 | Local dev, small teams, early stage |
| `soc2` | All modules | ~$30/month | Enterprise customers, SOC2 Type II audit |
| `hipaa` | All modules + 6yr retention | ~$50/month | Healthcare, medical data processing |

Switching profile:

```hcl
# terraform.tfvars
compliance_profile = "soc2"   # was "none"
```

```bash
terraform plan   # shows exactly what will be created
terraform apply  # ~2 minutes
```

## Modules

| Module | Controls | Disabled in `none` | Notes |
|--------|----------|-------------------|-------|
| [`kms`](./kms/) | SOC2 CC6.1 / HIPAA §164.312(a)(2)(iv) | ✓ | Required by all other modules |
| [`cloudtrail`](./cloudtrail/) | SOC2 CC7.2 / HIPAA §164.312(b) | ✓ | Multi-region, tamper-proof |
| [`vpc-flow-logs`](./vpc-flow-logs/) | SOC2 CC6.6 / HIPAA §164.312(b) | ✓ | ACCEPT + REJECT traffic |
| [`guardduty`](./guardduty/) | SOC2 CC7.1 | ✓ | EKS audit logs + S3 + malware scan |
| [`aws-config`](./aws-config/) | SOC2 CC6.1, CC7.2 | ✓ | 10 managed rules, continuous evaluation |
