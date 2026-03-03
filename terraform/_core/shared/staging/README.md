# _core/shared / staging

Cross-domain cluster foundation for the **staging** environment. Provisions the VPC, EKS control plane, shared IAM roles, developer access, and compliance controls.

This state is the **source of truth** for all domain `terraform_remote_state` data sources. All domain modules read cluster outputs from here — never duplicate `cluster_id`, `subnet_ids`, or `node_role_arn`.

## Configuration

| Setting | Value |
|---------|-------|
| Cluster | `staging-k8s` |
| Region | `eu-west-3` |
| Kubernetes | `1.32` |
| Compliance profile | `soc2` |
| NAT gateway | multi-AZ |
| GuardDuty | enabled |
| AWS Config | enabled |

## Apply

```bash
cd terraform/_core/shared/staging
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
| `variables.tf` | All input variables |
| `network.tf` | VPC module instantiation |
| `cluster.tf` | EKS module instantiation |
| `iam.tf` | IRSA roles for ESO + Cluster Autoscaler |
| `access.tf` | GitHub OIDC + IAM Identity Center |
| `compliance.tf` | Compliance controls (profile: `soc2`) |
| `outputs.tf` | Public API consumed by all domains |
| `terraform.tfvars` | Environment values *(gitignored)* |
| `terraform.tfvars.example` | Safe template to commit |

## Key outputs consumed by domains

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config  = {
    bucket = "k8s-platform-terraform-state"
    key    = "core/shared/staging/terraform.tfstate"
    region = "eu-west-3"
  }
}

local.cluster_id              = data.terraform_remote_state.shared.outputs.cluster_id
local.node_role_arn           = data.terraform_remote_state.shared.outputs.node_role_arn
local.private_subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids
local.cluster_oidc_issuer_url = data.terraform_remote_state.shared.outputs.cluster_oidc_issuer_url
```
