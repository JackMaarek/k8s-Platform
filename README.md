# k8s-platform

GitOps-first Kubernetes platform for PodYourLife — EKS on AWS, managed by Terraform and ArgoCD.

---

## Architecture overview

```
platform.yaml              ← source of truth (cluster version, env flags, Istio version)
      │
      ├── terraform/                    ← infrastructure
      │     ├── _core/
      │     │     ├── modules/aws/      ← reusable modules (vpc, eks, nodegroup, irsa, …)
      │     │     └── shared/           ← cluster foundation per env (VPC, EKS, IAM, access)
      │     │           ├── dev/
      │     │           ├── staging/
      │     │           └── prod/
      │     └── domains/
      │           └── platform/         ← node groups + domain IRSA
      │                 ├── dev/
      │                 ├── staging/
      │                 └── prod/
      │
      ├── argocd/                        ← GitOps delivery
      │     ├── projects/                ← AppProjects (platform, applications)
      │     ├── platform/                ← ApplicationSets for infra (Istio, monitoring, ESO…)
      │     └── applications/            ← product app ArgoCD Applications
      │
      └── kubernetes/
            ├── helm/
            │     ├── sample-app/        ← shared Helm chart for all product apps
            │     └── values/            ← per-app Helm value overrides
            └── secrets/                 ← ExternalSecret CRDs (sourced from AWS Secrets Manager)
```

---

## Apply order

Infrastructure layers are strictly ordered — each layer reads outputs from the one above via `terraform_remote_state`.

```
1. terraform/_core/shared/{env}
   └── provisions VPC, EKS, OIDC, IRSA roles → writes state to S3

2. terraform/domains/platform/{env}
   └── reads _core/shared state → provisions node groups, CoreDNS addon, domain IRSA

3. scripts/setup-local.sh  (or CI)
   └── configures kubectl → bootstraps ArgoCD → syncs all platform ApplicationSets
```

Never apply a domain before its `_core/shared` env. Never apply prod manually — use CI.

---

## Quick start (dev)

```bash
# 1. Bootstrap S3 + DynamoDB (once per AWS account)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://k8s-platform-terraform-state-${ACCOUNT_ID} --region eu-west-3
aws dynamodb create-table \
  --table-name k8s-platform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region eu-west-3

# 2. Configure terraform.tfvars
cd terraform/_core/shared/dev
cp terraform.tfvars.example terraform.tfvars
# fill in account IDs, update backend.tf bucket name with $ACCOUNT_ID

# 3. Apply cluster foundation
terraform init && terraform apply

# 4. Apply domain (node groups)
cd ../../../domains/platform/dev
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 5. Bootstrap ArgoCD
$(cd ../../_core/shared/dev && terraform output -raw configure_kubectl)
./scripts/setup-local.sh
```

---

## Secrets

All secrets live in **AWS Secrets Manager** under `{cluster-name}/{namespace}/{app}`. ESO syncs them into native Kubernetes Secrets. No secrets are stored in this repository.

```bash
# Add a secret (via platform-bot)
platform-bot secret add --name my-app/DB_PASSWORD --value <value>

# Manually
aws secretsmanager create-secret \
  --name dev-k8s/development/my-app \
  --secret-string '{"DB_PASSWORD":"xxx"}'
```

See `docs/examples/external-secret.yaml` for the ExternalSecret CRD pattern.

---

## Deploying an application

1. Add a Helm values file: `kubernetes/helm/values/<app>-dev.yaml`
2. Add an ArgoCD Application: `argocd/applications/<app>.yaml` (copy from `docs/examples/argocd-application.yaml`)
3. Commit and push — ArgoCD picks it up automatically

See `docs/examples/` for annotated templates.

---

## Access management

| Who | How | Permission |
|-----|-----|-----------|
| Developers | `aws sso login --profile dev-platform` | poweruser dev, readonly staging/prod |
| Maintainers | `aws sso login --profile dev-platform` | poweruser dev+staging, readonly prod |
| CI (GitHub Actions) | OIDC — no stored credentials | apply on main branch |
| Prod apply | **CI only** — no human apply | restricted by IAM trust policy |

After `terraform apply` on `_core/shared/dev`, set these GitHub secrets:
- `AWS_TERRAFORM_PLAN_ROLE_ARN` ← `terraform output github_plan_role_arn`
- `AWS_TERRAFORM_ROLE_ARN` ← `terraform output github_apply_role_arn`

---

## Compliance

| Control | dev | staging | prod |
|---------|-----|---------|------|
| CloudTrail | ✗ | ✓ 365d | ✓ 6yr |
| KMS CMK | ✗ | ✓ | ✓ (30d deletion window) |
| VPC Flow Logs | ✗ | ✓ | ✓ |
| GuardDuty | ✗ | ✓ | ✓ |
| AWS Config | ✗ | ✓ | ✓ |

Switch profile: change `compliance_profile` in `terraform.tfvars` and re-apply. No refactoring required.

---

## Estimated costs (eu-west-3, SPOT pricing)

| Env | Infra | Node groups | Total |
|-----|-------|------------|-------|
| dev | ~$30 | 2× t3.medium SPOT | ~$115/mo |
| staging | ~$130 (compliance + multi-AZ NAT) | 2× t3.medium SPOT | ~$222/mo |
| prod | ~$160 (HIPAA + multi-AZ NAT) | 3× t3.large ON_DEMAND | ~$260/mo |

GPU nodes (g4dn.xlarge) start at `desired_size = 0` — zero cost until a GPU workload is scheduled.

---

## Further reading

| Topic | Where |
|-------|-------|
| Cluster foundation (VPC, EKS, IRSA) | `terraform/_core/shared/{env}/README.md` |
| Node groups | `terraform/domains/platform/{env}/README.md` |
| Reusable modules | `terraform/_core/modules/README.md` |
| Adding a product app | `docs/examples/argocd-application.yaml` |
| Secret management | `docs/examples/external-secret.yaml` |
| GPU workloads | `docs/examples/gpu-workload.yaml` |
| First-time Terraform bootstrap | `docs/examples/terraform-new-env.md` |
| ArgoCD GitOps | `argocd/README.md` |
