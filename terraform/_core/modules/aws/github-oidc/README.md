# Module: github-oidc

Configures GitHub Actions as a trusted OIDC identity provider in AWS. Provisions two IAM roles — one for `terraform plan` (all branches) and one for `terraform apply` (main branch only).

No static credentials are stored in GitHub. The only GitHub secret is the role ARN.

## How it works

```
GitHub Actions workflow
  → requests OIDC token from GitHub
  → calls sts:AssumeRoleWithWebIdentity with token
  → AWS validates token against registered OIDC provider
  → returns temporary credentials (1h)
```

## Usage

```hcl
module "github_oidc" {
  source = "../../modules/github-oidc"

  cluster_name = "dev-k8s"
  github_org   = "PodYourLife"
  github_repo  = "k8s-platform"
  aws_region   = "eu-west-3"
  state_bucket = "k8s-platform-terraform-state"
  lock_table   = "k8s-platform-terraform-locks"
}
```

After apply, set these in GitHub → Settings → Secrets:

```
AWS_TERRAFORM_PLAN_ROLE_ARN  = <module.github_oidc.plan_role_arn>
AWS_TERRAFORM_ROLE_ARN       = <module.github_oidc.apply_role_arn>
```

In workflows:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_TERRAFORM_ROLE_ARN }}
    aws-region: eu-west-3
```

## Files

| File | Resources |
|------|-----------|
| `oidc_provider.tf` | `data.tls_certificate` (GitHub), `aws_iam_openid_connect_provider` |
| `iam_roles.tf` | `aws_iam_role` × 2 (plan + apply), `aws_iam_policy`, `aws_iam_role_policy_attachment` × 2 |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |
| tls | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | Cluster name — used as IAM role name prefix | `string` | — | yes |
| `github_org` | GitHub organization (e.g. `PodYourLife`) | `string` | — | yes |
| `github_repo` | GitHub repository (e.g. `k8s-platform`) | `string` | — | yes |
| `aws_region` | AWS region — scoped in apply policy resource ARNs | `string` | — | yes |
| `state_bucket` | S3 bucket name for Terraform state | `string` | — | yes |
| `lock_table` | DynamoDB table name for state locking | `string` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `plan_role_arn` | IAM role ARN for plan — set as `AWS_TERRAFORM_PLAN_ROLE_ARN` in GitHub secrets |
| `apply_role_arn` | IAM role ARN for apply — set as `AWS_TERRAFORM_ROLE_ARN` in GitHub secrets |
| `oidc_provider_arn` | GitHub OIDC provider ARN |
