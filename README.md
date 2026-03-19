# k8s-platform

GitOps-first Kubernetes platform for PodYourLife — EKS on AWS, managed by Terraform and ArgoCD.

---

## Architecture overview

```
platform.yaml              ← certified component versions + per-env state (managed by platform-bot)
      │
      ├── terraform/                    ← infrastructure
      │     ├── _core/
      │     │     ├── modules/aws/      ← reusable modules (vpc, eks, nodegroup, irsa, …)
      │     │     └── shared/           ← cluster foundation per env (VPC, EKS, IAM, access)
      │     │           ├── dev/
      │     │           ├── staging/
      │     │           └── prod/
      │     └── domains/
      │           ├── organization/     ← IAM Identity Center (org-level, all envs)
      │           └── platform/         ← node groups + domain IRSA
      │                 ├── dev/
      │                 ├── staging/
      │                 └── prod/
      │
      ├── argocd/                        ← GitOps delivery
      │     ├── projects/                ← AppProjects (platform, applications, ml)
      │     ├── platform/                ← ApplicationSets for infra (Istio, monitoring, ESO…)
      │     └── applications/            ← ArgoCD Applications
      │           └── ml/               ← ML batch pipeline Applications
      │
      └── kubernetes/
            ├── namespaces/              ← platform-managed namespaces (wave -3)
            ├── helm/
            │     ├── sample-app/        ← shared Helm chart for product apps (Deployment-based)
            │     ├── ml-batch-job/      ← shared Helm chart for ML batch pipelines (Job-based)
            │     └── values/            ← per-app Helm value overrides
            ├── manifests/               ← static platform manifests (dashboards, servicemonitors)
            └── secrets/                 ← ExternalSecret CRDs (sourced from AWS Secrets Manager)
```

---

## Apply order

Infrastructure layers are strictly ordered — each layer reads outputs from the one above via `terraform_remote_state`.

```
1. terraform/domains/organization
   └── IAM Identity Center: permission sets, groups, account assignments (all envs)
   └── runs once in the management account — no dependency on env state

2. terraform/_core/shared/{env}
   └── provisions VPC, EKS, OIDC, IRSA roles, CI access (GitHub OIDC) → writes state to S3

3. terraform/domains/platform/{env}
   └── reads _core/shared state → provisions node groups, CoreDNS addon, domain IRSA

4. platform-bot local up  (or CI)
   └── configures kubectl → bootstraps ArgoCD → syncs all platform ApplicationSets
   └── see docs/local-development.md for the full local bootstrap guide
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

# 2. Apply IAM Identity Center (once per AWS Organization / single-account)
cd terraform/domains/organization
cp terraform.tfvars.example terraform.tfvars
# fill in account IDs (single-account: all IDs equal)
terraform init && terraform apply

# 3. Configure terraform.tfvars
cd ../../_core/shared/dev
cp terraform.tfvars.example terraform.tfvars
# fill in account IDs, update backend.tf bucket name with $ACCOUNT_ID

# 4. Apply cluster foundation
terraform init && terraform apply

# 5. Apply domain (node groups)
cd ../../../domains/platform/dev
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 6. Bootstrap platform (local Kind cluster)
$(cd ../../_core/shared/dev && terraform output -raw configure_kubectl)
platform-bot local up --env dev
# See docs/local-development.md for the full walkthrough
```

---

## Secrets

All secrets live in **AWS Secrets Manager** under `{cluster-name}/{namespace}/{app}`. ESO syncs them into native Kubernetes Secrets. No secrets are stored in this repository.

```bash
# Manually add a secret
aws secretsmanager create-secret \
  --name dev-k8s/development/my-app \
  --secret-string '{"DB_PASSWORD":"xxx"}'
```

See `docs/examples/external-secret.yaml` for the ExternalSecret CRD pattern.

---

## Deploying a product application

1. Add a Helm values file: `kubernetes/helm/values/<app>-dev.yaml`
2. Add an ArgoCD Application: `argocd/applications/<app>.yaml` (copy from `docs/examples/argocd-application.yaml`)
3. Commit and push — ArgoCD picks it up automatically

See `docs/examples/` for annotated templates.

---

## Deploying an ML batch pipeline

1. Add a values file: `kubernetes/helm/values/<app>-dev.yaml` (copy from `kubernetes/helm/values/quanvnn-dev.yaml`)
2. Add an ArgoCD Application: `argocd/applications/ml/<app>.yaml` (copy from `argocd/applications/ml/quanvnn.yaml`)
3. Set `job.runId` in the values file to trigger the first run
4. Commit and push — ArgoCD syncs the Jobs automatically

To trigger a new run: increment `job.runId` in the values file and commit.
Both Jobs (GPU extract + CPU train) are recreated under the new name.
Previous Completed jobs are retained for log inspection and can be pruned manually.

The GPU node group starts at `desired_size = 0` — zero compute cost when no Job is running.
See `kubernetes/helm/ml-batch-job/values.yaml` for all available configuration options.

---

## Namespaces

All namespaces are platform-managed — declared in `kubernetes/namespaces/` and deployed by the
`namespaces` ApplicationSet (wave -3). No namespace is ever created manually or by an application chart.

| Namespace | Domain | Istio injection | PSS |
|---|---|---|---|
| `argocd` | GitOps | enabled | restricted |
| `istio-system` | Service mesh | disabled | privileged |
| `monitoring` | Observability | disabled | privileged |
| `external-secrets` | Secret sync | enabled | restricted |
| `kyverno` | Policy | enabled | restricted |
| `finops` | Cost monitoring | disabled | restricted |
| `ml` | ML batch workloads | enabled (Jobs opt-out via annotation) | restricted |
| `development` | Product apps dev | enabled | restricted |
| `staging` | Product apps staging | enabled | restricted |
| `production` | Product apps prod | enabled | restricted |

---

## Access management

| Who | How | Permission |
|-----|-----|-----------|
| Developers | `aws sso login --profile dev-platform` | poweruser dev, readonly staging/prod |
| Maintainers | `aws sso login --profile dev-platform` | poweruser dev+staging, readonly prod |
| CI (GitHub Actions) | OIDC — no stored credentials | apply on main branch |
| Prod apply | **CI only** — no human apply | restricted by IAM trust policy |

IAM Identity Center (permission sets, groups, account assignments) is managed in
`terraform/domains/organization/` — a single root for all environments. `_core/shared/{env}`
only handles CI access (GitHub Actions OIDC).

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
| IAM Identity Center (org-level) | `terraform/domains/organization/` |
| Node groups | `terraform/domains/platform/{env}/README.md` |
| Reusable Terraform modules | `terraform/_core/modules/README.md` |
| Adding a product app | `docs/examples/argocd-application.yaml` |
| Adding an ML pipeline | `kubernetes/helm/values/quanvnn-dev.yaml` |
| ML chart configuration | `kubernetes/helm/ml-batch-job/values.yaml` |
| Secret management | `docs/examples/external-secret.yaml` |
| Cost monitoring (OpenCost) | `argocd/platform/opencost/opencost.yaml` |
| First-time Terraform bootstrap | `docs/examples/terraform-new-env.md` |
