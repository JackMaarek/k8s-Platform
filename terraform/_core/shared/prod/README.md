# _core/shared / prod

Cross-domain cluster foundation for the **prod** environment.

**Humans cannot apply prod from a local machine.** All prod applies go through CI (GitHub Actions, main branch, manual approval gate in the GitHub Environment). The apply IAM role trust policy enforces this — `sts:AssumeRoleWithWebIdentity` is restricted to `repo:PodYourLife/k8s-platform:ref:refs/heads/main`.

**Ownership**: platform-maintainers review and approve. CI applies.

---

## What gets provisioned

```
VPC (10.2.0.0/16)
  ├── private subnets: 10.2.1.0/24, 10.2.2.0/24, 10.2.3.0/24  (eu-west-3a/b/c)
  ├── public  subnets: 10.2.101.0/24, 10.2.102.0/24, 10.2.103.0/24
  └── 3 NAT gateways  (one per AZ — required for AZ-level isolation in prod)

EKS cluster: prod-k8s  (Kubernetes 1.33)
  ├── OIDC provider              → enables IRSA for all service accounts
  ├── Add-ons: vpc-cni, kube-proxy, coredns, pod-identity-agent
  ├── CloudWatch log group       → control plane logs, 30 days retention
  └── API endpoint access        → restrict public_access_cidrs before go-live

IRSA roles
  ├── prod-k8s-eso-role          → external-secrets SA → Secrets Manager prod-k8s/*
  ├── prod-k8s-autoscaler-role
  └── prod-k8s-aws-lbc-role

Access
  ├── GitHub Actions OIDC        → plan (all branches) + apply (main only, CI-only)
  └── IAM Identity Center        → platform-devs (readonly) + platform-maintainers (readonly)

Compliance: hipaa
  ├── KMS CMK          (HIPAA §164.312(a)(2)(iv)) — 30 day deletion window
  ├── CloudTrail       (HIPAA §164.312(b))         — 2190 day retention (6yr)
  ├── VPC Flow Logs    (HIPAA §164.312(b))         — 2190 day retention
  ├── GuardDuty        (SOC2 CC7.1)                — EKS + S3 + malware scan
  └── AWS Config       (SOC2 CC6.1, CC7.2)         — 10 managed rules
```

---

## Prerequisites

S3 bucket and DynamoDB table must exist. See `_core/shared/dev/README.md` bootstrap section.

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace account IDs, update backend.tf bucket name
```

---

## Applying prod

Prod is applied exclusively by CI after merge to main. To trigger:

1. Open a PR with the change
2. CI runs `terraform plan` and comments the diff on the PR
3. Merge to main after approval
4. CI applies dev → staging → prod in sequence, each with a manual approval gate in GitHub Environments

**Emergency break-glass** (platform-maintainer + documented incident required):

```bash
# Assumes you have temporary elevated access via IAM Identity Center
cd terraform/_core/shared/prod
export AWS_PROFILE=prod-breakglass
terraform init
terraform plan   # verify scope — never apply unreviewed changes
```

---

## Differences from staging

| Aspect | staging | prod |
|--------|---------|------|
| VPC CIDR | `10.1.0.0/16` | `10.2.0.0/16` |
| Node capacity type | SPOT | ON_DEMAND (standard) |
| Log retention | 14 days | 30 days |
| Compliance | `soc2` | `hipaa` |
| Audit log retention | 365 days | 2190 days (6yr — HIPAA §164.530(j)) |
| KMS deletion window | 7 days | 30 days (max, HIPAA) |
| Human apply | allowed (poweruser) | **blocked** — CI only |
| Developer access | poweruser | readonly |

---

## Key outputs consumed by domains

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "k8s-platform-terraform-state-<ACCOUNT_ID>"
    key    = "core/shared/prod/terraform.tfstate"
    region = "eu-west-3"
  }
}

locals {
  cluster_id              = data.terraform_remote_state.shared.outputs.cluster_id
  node_role_arn           = data.terraform_remote_state.shared.outputs.node_role_arn
  private_subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_oidc_issuer_url = data.terraform_remote_state.shared.outputs.cluster_oidc_issuer_url
}
```

Same full output contract as dev and staging — see `dev/README.md` for the complete output reference.

---

## ⚠️ Before go-live checklist

- [ ] Replace `public_access_cidrs = ["0.0.0.0/0"]` with office/VPN CIDR range
- [ ] Confirm `compliance_profile = "hipaa"` in `terraform.tfvars`
- [ ] Sign AWS Business Associate Agreement (BAA) — required for HIPAA
- [ ] Verify `terraform output kms_compliance_key_arn` is non-null
- [ ] Verify `terraform output cloudtrail_bucket` exists and has versioning enabled
- [ ] Rotate all secrets under `prod-k8s/*` in AWS Secrets Manager after first apply
- [ ] Add human approver to GitHub Environment `prod-apply`

---

## Files

| File | Responsibility |
|------|---------------|
| `backend.tf` | S3 remote state — key `core/shared/prod/terraform.tfstate` |
| `versions.tf` | Terraform `>= 1.6.0`, AWS `~> 5.0`, TLS `~> 4.0` |
| `providers.tf` | AWS provider, default tags: `Environment=prod`, `Layer=core-shared` |
| `variables.tf` | Input variables — `kubernetes_version` default `1.33`, `log_retention_days` default `30` |
| `network.tf` | VPC `10.2.0.0/16`, 3 AZs, multi-AZ NAT gateways |
| `cluster.tf` | EKS `prod-k8s` 1.33, CloudWatch logs `30d` |
| `iam.tf` | IRSA: `irsa_eso`, `irsa_cluster_autoscaler`, `irsa_aws_lbc` |
| `access.tf` | GitHub OIDC (plan all branches, apply main-only), IAM Identity Center |
| `compliance.tf` | HIPAA controls — KMS (30d deletion), CloudTrail + VPC Flow Logs (6yr), GuardDuty, Config |
| `outputs.tf` | Public API — same contract as dev and staging |
| `terraform.tfvars` | Actual values — **gitignored**, never commit, never share outside platform-maintainers |
| `terraform.tfvars.example` | Committed template |
