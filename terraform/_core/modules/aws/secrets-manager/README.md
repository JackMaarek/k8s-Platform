# Module: secrets-manager

Creates an AWS Secrets Manager secret under a namespaced path `{path}/{name}`. Intended to be called by `platform-bot secret add` — domain teams never provision secrets manually.

The ESO `ClusterSecretStore` in `_core/shared` has read access to `{cluster_name}/*`, so any secret created under that prefix is automatically available to `ExternalSecret` CRDs.

## Usage

```hcl
module "secret_supabase" {
  source = "../../modules/secrets-manager"

  path          = "dev-k8s/platform"
  name          = "supabase-url"
  domain        = "platform"
  description   = "Supabase project URL for lpcdm"
  secret_string = "https://your-project.supabase.co"  # rotated after first apply
}
```

Reference in an `ExternalSecret` CRD:

```yaml
spec:
  dataFrom:
    - extract:
        key: dev-k8s/platform/supabase-url
```

## Files

| File | Resources |
|------|-----------|
| `secret.tf` | `aws_secretsmanager_secret`, `aws_secretsmanager_secret_version` |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `path` | Secret path prefix. Convention: `{cluster}/{domain}` | `string` | — | yes |
| `name` | Secret name — appended to path | `string` | — | yes |
| `domain` | Domain that owns this secret | `string` | — | yes |
| `description` | Human-readable description | `string` | `""` | no |
| `secret_string` | Initial secret value. Rotated outside Terraform after creation. | `string` *(sensitive)* | — | yes |
| `recovery_window_days` | Days before permanent deletion after destroy. Use `0` in dev. | `number` | `7` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `secret_arn` | Secret ARN — used in IRSA policy `resources` |
| `secret_name` | Full secret name including path — referenced in ExternalSecret CRDs |
