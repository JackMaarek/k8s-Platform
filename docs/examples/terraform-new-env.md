# Terraform — bootstrapping a new environment

Follow this sequence exactly. Each layer depends on the previous one.

## Prerequisites

```bash
# 1. Create the S3 backend + DynamoDB lock table (one-shot, shared across envs)
aws s3 mb s3://k8s-platform-terraform-state-<ACCOUNT_ID> \
  --region eu-west-3

aws dynamodb create-table \
  --table-name k8s-platform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-3

# 2. Set real account IDs in terraform.tfvars (replace placeholders)
#    __AWS_ACCOUNT_ID_DEV__     → your dev account ID
#    __AWS_ACCOUNT_ID_STAGING__ → your staging account ID
#    __AWS_ACCOUNT_ID_PROD__    → your prod account ID
```

## Layer 1 — `_core/shared/{env}`

Provisions VPC, EKS control plane, OIDC provider, IRSA roles (ESO, autoscaler, LBC).

```bash
cd terraform/_core/shared/dev

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Outputs you'll need for layer 2
terraform output cluster_id
terraform output cluster_oidc_issuer_url
terraform output configure_kubectl
```

## Layer 2 — `domains/platform/{env}`

Provisions node groups (standard + GPU) and domain-level IRSA roles.
Depends on layer 1 remote state — run only after layer 1 is applied.

```bash
cd terraform/domains/platform/dev

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Layer 3 — Configure kubectl + bootstrap ArgoCD

```bash
# Configure kubectl
aws eks update-kubeconfig --region eu-west-3 --name dev-k8s

# Verify nodes are Ready
kubectl get nodes

# Bootstrap the platform (ArgoCD, namespaces, projects, platform apps)
./scripts/setup-local.sh
```

## Adding environments

To activate staging or prod, update `platform.yaml`:

```yaml
environments:
  staging:
    enabled: true    # was false
```

Then run `platform-bot sync` to propagate to tfvars and ApplicationSets,
and repeat layers 1→2 for the new env.

## Estimated costs (eu-west-3, SPOT pricing)

| Env     | Node group          | $/month (approx) |
|---------|---------------------|-----------------|
| dev     | 2× t3.medium SPOT   | ~$115           |
| staging | 2× t3.medium SPOT   | ~$222           |
| prod    | 3× t3.large ON_DEMAND | ~$260         |
| **Total** |                   | **~$597**       |

GPU nodes (g4dn.xlarge) start at desired=0 — zero cost until scheduled.
