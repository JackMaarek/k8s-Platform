# domains/platform

Platform team domain — node groups and IRSA roles for platform workloads (ArgoCD, Istio, Prometheus, ESO, Cluster Autoscaler).

## Environments

| Environment | State key |
|-------------|-----------|
| [`dev`](./dev/) | `domains/platform/dev/terraform.tfstate` |
| [`staging`](./staging/) | `domains/platform/staging/terraform.tfstate` |
| [`prod`](./prod/) | `domains/platform/prod/terraform.tfstate` |

## Depends on

`_core/shared/{env}` must be applied before this domain in each environment.
