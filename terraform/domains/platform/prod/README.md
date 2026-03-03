# domains/platform / prod

Platform domain infrastructure for **prod** — node groups and IRSA roles for platform workloads.

Reads cluster foundation from `_core/shared/prod` via `terraform_remote_state`. Never re-declares VPC, EKS, or shared IAM resources.

## Configuration

| Setting | Value |
|---------|-------|
| Cluster | `prod-k8s` |
| Shared state | `core/shared/prod/terraform.tfstate` |
| Node groups | standard (ON_DEMAND) + gpu (scale-to-zero) |

## Managing node groups

Node groups are driven by `var.node_groups` in `terraform.tfvars` — no code change required.

```hcl
# Add a node group: add a block in terraform.tfvars
node_groups = {
  standard = { ... }
  gpu      = { ... }   # remove this block to destroy GPU nodes
  quantum  = { ... }   # new block = new node group on next apply
}
```

Or via platform-bot:
```bash
platform-bot nodegroup add --domain platform --env prod --name quantum --type c5.2xlarge
platform-bot nodegroup remove --domain platform --env prod --name gpu
```

## Apply

> Always apply `_core/shared/prod` first.

```bash
cd terraform/domains/platform/prod
terraform init
terraform plan
terraform apply
```

## Files

| File | Responsibility |
|------|---------------|
| `backend.tf` | S3 remote state configuration |
| `versions.tf` | Provider version pinning |
| `providers.tf` | AWS provider + default tags |
| `variables.tf` | Input variables including `node_groups` map |
| `shared.tf` | `terraform_remote_state` + locals from `_core/shared/prod` |
| `nodegroups.tf` | `for_each` on `var.node_groups` — never edit directly |
| `irsa.tf` | IRSA roles for platform workloads (ArgoCD image updater) |
| `outputs.tf` | Domain outputs |
| `terraform.tfvars` | Node groups + env config *(gitignored)* |
| `terraform.tfvars.example` | Documented template with examples |
