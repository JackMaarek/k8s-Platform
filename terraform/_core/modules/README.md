# _core/modules

Reusable, single-responsibility Terraform modules. Each module provisions one logical AWS component and nothing else.

Modules are consumed by `_core/shared/{env}` and `domains/{domain}/{env}`. Never instantiated directly by developers — always via a domain or shared environment.

## Modules

| Module | Responsibility | Consumed by |
|--------|---------------|-------------|
| [`vpc`](./vpc/) | VPC, subnets, NAT gateway, route tables | `_core/shared` |
| [`eks`](./eks/) | EKS cluster, IAM roles, OIDC provider, add-ons | `_core/shared` |
| [`nodegroup`](./nodegroup/) | EKS managed node group + launch template | `_core/shared`, `domains/*` |
| [`irsa`](./irsa/) | IAM Role for Service Account (OIDC trust + policy) | `_core/shared`, `domains/*` |
| [`secrets-manager`](./secrets-manager/) | AWS Secrets Manager secret creation | `platform-bot` |
| [`github-oidc`](./github-oidc/) | GitHub Actions OIDC provider + CI IAM roles | `_core/shared` |
| [`identity-center`](./identity-center/) | IAM Identity Center permission sets + group assignments | `_core/shared` |
| [`compliance/kms`](./compliance/kms/) | Customer-managed KMS key with auto-rotation | `_core/shared` (via compliance_profile) |
| [`compliance/cloudtrail`](./compliance/cloudtrail/) | CloudTrail + encrypted immutable audit log bucket | `_core/shared` (via compliance_profile) |
| [`compliance/guardduty`](./compliance/guardduty/) | GuardDuty threat detection | `_core/shared` (via compliance_profile) |
| [`compliance/vpc-flow-logs`](./compliance/vpc-flow-logs/) | VPC network traffic capture | `_core/shared` (via compliance_profile) |
| [`compliance/aws-config`](./compliance/aws-config/) | AWS Config recorder + 10 managed compliance rules | `_core/shared` (via compliance_profile) |

## Adding a new module

1. Create `_core/modules/{name}/`
2. Split resources by type: one file per AWS resource type
3. Add `variables.tf`, `outputs.tf`, `README.md`
4. Instantiate in the appropriate `_core/shared/{env}` or `domains/{domain}/{env}` file
