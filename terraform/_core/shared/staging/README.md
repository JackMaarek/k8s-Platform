# _core/shared / staging

Cross-domain cluster foundation for the **staging** environment.

Identical layer structure to dev with three key differences: multi-AZ NAT gateways for fault isolation, SOC2 compliance profile active, and the API endpoint access should be restricted before go-live. Staging mirrors prod topology — if it works here, it works in prod.

**Ownership**: platform-maintainers only. Applying staging requires PR approval from at least one maintainer. CI applies automatically on merge to main.

---

## What gets provisioned

```
VPC (10.1.0.0/16)
  ├── private subnets: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24  (eu-west-3a/b/c)
  ├── public  subnets: 10.1.101.0/24, 10.1.102.0/24, 10.1.103.0/24
  └── 3 NAT gateways  (one per AZ — fault isolation, ~$100/month)

EKS cluster: staging-k8s  (Kubernetes 1.33)
  ├── OIDC provider              → enables IRSA for all service accounts
  ├── Add-ons: vpc-cni, kube-proxy, coredns, pod-identity-agent
  └── CloudWatch log group       → control plane logs, 14 days retention

IRSA roles
  ├── staging-k8s-eso-role       → external-secrets SA → Secrets Manager staging-k8s/*
  ├── staging-k8s-autoscaler-role
  └── staging-k8s-aws-lbc-role

Access
  ├── GitHub Actions OIDC        → plan (all branches) + apply (main only)
  └── IAM Identity Center        → platform-devs (readonly) + platform-maintainers (poweruser)

Compliance: soc2
  ├── KMS CMK          (SOC2 CC6.1)
  ├── CloudTrail       (SOC2 CC7.2) — 365 day retention
  ├── VPC Flow Logs    (SOC2 CC6.6) — 365 day retention
  ├── GuardDuty        (SOC2 CC7.1) — EKS + S3 + malware scan
  └── AWS Config       (SOC2 CC6.1, CC7.2) — 10 managed rules
```

---

## Prerequisites

S3 bucket and DynamoDB table must exist (same resources as dev — shared per account). See `_core/shared/dev/README.md` bootstrap section if not yet created.

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace account IDs, update backend.tf bucket name
```

---

## Apply

> Always apply `_core/shared/staging` before `domains/platform/staging`.

```bash
cd terraform/_core/shared/staging

terraform init
terraform plan -out=tfplan
terraform apply tfplan

$(terraform output -raw configure_kubectl)
```

---

## Differences from dev

| Aspect | dev | staging |
|--------|-----|---------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| AZs | 2 | 3 |
| NAT gateways | 1 (single) | 3 (one per AZ) |
| Log retention | 7 days | 14 days |
| Compliance | `none` | `soc2` |
| GuardDuty | disabled | enabled |
| AWS Config | disabled | enabled |
| Developer access | poweruser | readonly |

---

## Key outputs consumed by domains

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "k8s-platform-terraform-state-<ACCOUNT_ID>"
    key    = "core/shared/staging/terraform.tfstate"
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

Same full output contract as dev — see `dev/README.md` for the complete output reference table.

---

## Files

| File | Responsibility |
|------|---------------|
| `backend.tf` | S3 remote state — key `core/shared/staging/terraform.tfstate` |
| `versions.tf` | Terraform `>= 1.6.0`, AWS `~> 5.0`, TLS `~> 4.0` |
| `providers.tf` | AWS provider, default tags: `Environment=staging`, `Layer=core-shared` |
| `variables.tf` | Input variables — `kubernetes_version` default `1.33`, `log_retention_days` default `14` |
| `network.tf` | VPC `10.1.0.0/16`, 3 AZs, multi-AZ NAT gateways (`single_nat_gateway = false`) |
| `cluster.tf` | EKS `staging-k8s` 1.33, CloudWatch logs `14d` |
| `iam.tf` | IRSA: `irsa_eso`, `irsa_cluster_autoscaler`, `irsa_aws_lbc` |
| `access.tf` | GitHub OIDC (plan + apply roles), IAM Identity Center groups |
| `compliance.tf` | SOC2 controls — KMS, CloudTrail, VPC Flow Logs, GuardDuty, AWS Config |
| `outputs.tf` | Public API — same contract as dev |
| `terraform.tfvars` | Actual values — **gitignored** |
| `terraform.tfvars.example` | Committed template |
