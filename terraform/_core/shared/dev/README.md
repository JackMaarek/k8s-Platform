# _core/shared / dev

Cross-domain cluster foundation for the **dev** environment.

This Terraform root provisions everything a domain team needs to deploy workloads: VPC, EKS control plane, OIDC provider, shared IAM roles (node role + IRSA roles for cluster add-ons), developer access via IAM Identity Center, and CI access via GitHub Actions OIDC. Compliance controls are disabled in dev (`profile: none`) to reduce cost and iteration friction.

**Ownership**: platform-maintainers only. Domain teams consume outputs via `terraform_remote_state` — they never modify this layer.

---

## What gets provisioned

```
VPC (10.0.0.0/16)
  ├── private subnets: 10.0.1.0/24, 10.0.2.0/24  (eu-west-3a, eu-west-3b)
  ├── public  subnets: 10.0.101.0/24, 10.0.102.0/24
  └── 1 NAT gateway   (single — saves ~$65/month vs one per AZ)

EKS cluster: dev-k8s  (Kubernetes 1.33)
  ├── OIDC provider              → enables IRSA for all service accounts
  ├── Add-ons: vpc-cni, kube-proxy, coredns, pod-identity-agent
  └── CloudWatch log group       → control plane logs, 7 days retention

IRSA roles (no static credentials anywhere)
  ├── dev-k8s-eso-role           → external-secrets SA  → Secrets Manager dev-k8s/*
  ├── dev-k8s-autoscaler-role    → cluster-autoscaler SA → autoscaling:* + ec2:Describe*
  └── dev-k8s-aws-lbc-role       → aws-load-balancer-controller SA → ec2/elb/acm/waf/shield

Access
  ├── GitHub Actions OIDC        → plan (all branches) + apply (main only), no stored credentials
  └── IAM Identity Center        → platform-devs (poweruser dev) + platform-maintainers

Compliance: none
  └── All compliance modules disabled (CloudTrail, KMS, GuardDuty, Config, VPC Flow Logs)
      Enable by setting compliance_profile = "soc2" or "hipaa" in terraform.tfvars
```

---

## Prerequisites

Before the first `terraform init`, the S3 bucket and DynamoDB table must exist:

```bash
# One-time bootstrap — shared across all envs (run once per AWS account)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3 mb s3://k8s-platform-terraform-state-${ACCOUNT_ID} \
  --region eu-west-3

aws s3api put-bucket-versioning \
  --bucket k8s-platform-terraform-state-${ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name k8s-platform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-3
```

Then prepare `terraform.tfvars` from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace __AWS_ACCOUNT_ID_*__ with real AWS account IDs
# The bucket name in backend.tf must also be updated with your ACCOUNT_ID
```

---

## Apply

> `_core/shared/dev` must be applied **before** `domains/platform/dev` — domains read outputs from this state.

```bash
cd terraform/_core/shared/dev

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl after apply
$(terraform output -raw configure_kubectl)
```

---

## Post-apply: set GitHub secrets

After the first apply, capture the CI role ARNs and store them in GitHub:

```bash
terraform output github_plan_role_arn   # → AWS_TERRAFORM_PLAN_ROLE_ARN
terraform output github_apply_role_arn  # → AWS_TERRAFORM_ROLE_ARN
```

GitHub → Settings → Secrets and variables → Actions → New repository secret.

---

## Post-apply: add developers

```bash
# Get the group IDs from Terraform output
terraform output group_id_platform_devs
terraform output group_id_platform_maintainers
```

AWS console → IAM Identity Center → Groups → select group → Add users.
Developer daily workflow:

```bash
aws sso login --profile dev-platform
export AWS_PROFILE=dev-platform
kubectl get nodes
```

---

## Key outputs consumed by domains

All domain roots read this state via `terraform_remote_state`. The contract is stable — outputs are never renamed or removed without a migration plan.

```hcl
# domains/platform/dev/shared.tf
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "k8s-platform-terraform-state-<ACCOUNT_ID>"
    key    = "core/shared/dev/terraform.tfstate"
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

Full output reference:

| Output | Consumed by |
|--------|-------------|
| `cluster_id` | `nodegroup` modules in all domains |
| `node_role_arn` | `nodegroup` modules in all domains |
| `private_subnet_ids` | `nodegroup` modules in all domains |
| `cluster_oidc_issuer_url` | `irsa` modules in all domains |
| `oidc_provider_arn` | `irsa` modules in all domains |
| `eso_role_arn` | ArgoCD Application `external-secrets` (Helm values) |
| `cluster_autoscaler_role_arn` | ArgoCD Application `cluster-autoscaler` (Helm values) |
| `aws_lbc_role_arn` | ArgoCD Application `aws-load-balancer-controller` (Helm values) |
| `configure_kubectl` | Developer onboarding / CI post-apply |
| `github_plan_role_arn` | GitHub secret `AWS_TERRAFORM_PLAN_ROLE_ARN` |
| `github_apply_role_arn` | GitHub secret `AWS_TERRAFORM_ROLE_ARN` |
| `kms_compliance_key_arn` | Domain secrets, RDS, S3 encryption (null in `none` profile) |

---

## Enabling compliance controls

Compliance controls are additive — enabling them never destroys existing resources:

```hcl
# terraform.tfvars
compliance_profile = "soc2"   # was "none"
```

```bash
terraform plan   # previews: CloudTrail, KMS CMK, VPC Flow Logs, GuardDuty, AWS Config
terraform apply  # ~2 minutes
```

| Profile | Controls | Monthly cost (eu-west-3) |
|---------|----------|--------------------------|
| `none`  | — | $0 |
| `soc2`  | CloudTrail + KMS + VPC Flow Logs + GuardDuty + AWS Config | ~$30 |
| `hipaa` | soc2 + 6yr log retention + stricter KMS | ~$50 |

---

## Files

| File | Responsibility |
|------|---------------|
| `backend.tf` | S3 remote state — bucket `k8s-platform-terraform-state-<ACCOUNT_ID>`, key `core/shared/dev/terraform.tfstate` |
| `versions.tf` | Terraform `>= 1.6.0`, AWS `~> 5.0`, TLS `~> 4.0` — update with `terraform init -upgrade` |
| `providers.tf` | AWS provider, default tags: `Environment=dev`, `Layer=core-shared` |
| `variables.tf` | All input variables — see `terraform.tfvars.example` for values |
| `network.tf` | VPC `10.0.0.0/16`, 2 AZs, single NAT gateway |
| `cluster.tf` | EKS `dev-k8s` 1.33, CloudWatch logs `7d` |
| `iam.tf` | IRSA: `irsa_eso`, `irsa_cluster_autoscaler`, `irsa_aws_lbc` |
| `access.tf` | GitHub OIDC (plan + apply roles), IAM Identity Center groups |
| `compliance.tf` | Conditional compliance modules — all disabled at `profile: none` |
| `outputs.tf` | Public API — do not remove or rename outputs |
| `terraform.tfvars` | Actual values — **gitignored**, never commit |
| `terraform.tfvars.example` | Committed template, safe to share |

---

## Common operations

**Upgrade Kubernetes version** — update `platform.yaml` at repo root, then run `platform-bot sync`:

```bash
# Manual equivalent:
# 1. Update kubernetes_version in terraform.tfvars
# 2. terraform plan → confirm only the cluster version changes
# 3. terraform apply → EKS performs a rolling upgrade (~15 min)
```

**Upgrade provider versions**:

```bash
terraform init -upgrade
terraform plan   # verify no unexpected changes
```

**Destroy** (dev only — never destroy staging/prod manually):

```bash
# Domains must be destroyed first
cd terraform/domains/platform/dev && terraform destroy
cd terraform/_core/shared/dev     && terraform destroy
```
