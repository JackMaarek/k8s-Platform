# Module: irsa

Provisions an IAM Role for Service Account (IRSA) — maps a Kubernetes service account to an AWS IAM role via OIDC web identity federation.

Each call to this module = one service account gets AWS permissions. Domain teams use this module to grant their workloads access to AWS services (S3, Secrets Manager, SQS, etc.) without touching the shared node role.

## Usage

```hcl
module "irsa_eso" {
  source = "../../modules/irsa"

  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  role_name               = "dev-k8s-eso-role"
  namespace               = "external-secrets"
  service_account_name    = "external-secrets"

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = ["arn:aws:secretsmanager:eu-west-3:*:secret:dev-k8s/*"]
    }
  ]
}
```

Annotate the Kubernetes service account with the output role ARN:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: <module.irsa_eso.role_arn>
```

## Files

| File | Resources |
|------|-----------|
| `iam_role.tf` | `data.aws_caller_identity`, `data.aws_iam_policy_document` (trust), `aws_iam_role` |
| `iam_policy.tf` | `data.aws_iam_policy_document` (permissions), `aws_iam_policy`, `aws_iam_role_policy_attachment` |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_oidc_issuer_url` | OIDC issuer URL — from `_core/shared` outputs | `string` | — | yes |
| `role_name` | IAM role name. Convention: `{cluster}-{service}-role` | `string` | — | yes |
| `namespace` | Kubernetes namespace of the service account | `string` | — | yes |
| `service_account_name` | Kubernetes service account name | `string` | — | yes |
| `policy_statements` | IAM policy statements granting AWS permissions | `list(object)` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | IAM role ARN — annotate on the Kubernetes service account |
| `role_name` | IAM role name |
