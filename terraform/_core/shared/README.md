# _core/shared

Cross-domain cluster foundation — provisioned once per environment, consumed by all domains via `terraform_remote_state`.

## Environments

| Environment | Compliance | State key |
|-------------|-----------|-----------|
| [`dev`](./dev/) | `none` | `core/shared/dev/terraform.tfstate` |
| [`staging`](./staging/) | `soc2` | `core/shared/staging/terraform.tfstate` |
| [`prod`](./prod/) | `hipaa` | `core/shared/prod/terraform.tfstate` |

## Apply order

Always apply `_core/shared` before any domain — domains consume shared outputs via remote state.

```
_core/shared/dev  →  domains/*/dev
_core/shared/staging  →  domains/*/staging
_core/shared/prod  →  domains/*/prod
```

## Public API

`outputs.tf` in each environment is the contract with all domain teams. Never remove or rename an output without coordinating with domain teams first.
