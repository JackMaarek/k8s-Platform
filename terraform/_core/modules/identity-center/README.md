# Module: identity-center

Provisions AWS IAM Identity Center permission sets and group assignments for human developer access. Zero static credentials — developers authenticate via SSO and receive temporary IAM tokens.

**IdP-agnostic** — the identity provider (AWS native, Okta, Google Workspace, Keycloak) is configured at the AWS IAM Identity Center level via SAML/SCIM. Swapping IdPs requires no changes to this module.

## Access matrix

| Group | dev | staging | prod |
|-------|-----|---------|------|
| `platform-devs` | PowerUser | ReadOnly | ReadOnly |
| `platform-maintainers` | PowerUser | PowerUser (no prod write) | ReadOnly |
| CI (GitHub Actions OIDC) | apply | apply | apply |

> Prod apply is CI-only. No human can apply to prod from a local machine.

## Developer workflow

```bash
# One-time setup
aws configure sso --profile dev-platform

# Daily
aws sso login --profile dev-platform
export AWS_PROFILE=dev-platform
terraform plan
```

## Switching to Okta / Google / Keycloak

1. In AWS console → IAM Identity Center → Settings → Identity source → Change to external IdP
2. Configure SAML metadata + SCIM provisioning endpoint
3. Groups sync automatically via SCIM — this module is not modified

## Files

| File | Resources |
|------|-----------|
| `permission_sets.tf` | `data.aws_ssoadmin_instances`, `aws_ssoadmin_permission_set` × 3, `aws_ssoadmin_managed_policy_attachment` × 3, `aws_ssoadmin_permission_set_inline_policy` × 2 |
| `group_assignments.tf` | `aws_identitystore_group` × 2, `aws_ssoadmin_account_assignment` × 5 |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | Cluster name — used as permission set name prefix | `string` | — | yes |
| `account_id_dev` | AWS account ID for dev | `string` | — | yes |
| `account_id_staging` | AWS account ID for staging | `string` | — | yes |
| `account_id_prod` | AWS account ID for prod | `string` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `group_id_platform_devs` | Identity store group ID — add users in AWS console or via SCIM |
| `group_id_platform_maintainers` | Identity store group ID for maintainers |
| `permission_set_arn_readonly` | ReadOnly permission set ARN — reused by domain modules |
| `permission_set_arn_poweruser_dev` | PowerUser dev permission set ARN |
| `sso_instance_arn` | IAM Identity Center instance ARN — reused when adding domain groups |
| `identity_store_id` | Identity store ID — reused when adding domain groups |
