# terraform

Domain-Driven infrastructure as code for k8s-platform.

## Structure

```
terraform/
  _core/
    modules/          # Reusable SRP modules (vpc, eks, nodegroup, irsa, secrets-manager)
    shared/           # Cross-domain cluster foundation (VPC, EKS, OIDC, ESO, Autoscaler)
      dev/
      staging/
      prod/
  domains/
    platform/         # Platform team — node groups, ArgoCD image updater IRSA
      dev/
      staging/
      prod/
    {domain}/         # Added by: platform-bot domain add --name {domain} --team {team}
  _ci/
    .terraform-version
    .tflint.hcl
    .pre-commit-config.yaml
    github-actions/
```

## Apply order

Always apply `_core/shared` before any domain — domains consume shared outputs via remote state.

```
_core/shared/dev  →  domains/platform/dev  →  domains/*/dev
_core/shared/staging  →  ...
_core/shared/prod  →  ...
```

## Bootstrap (first time)

```bash
# 1. Create state backend (once per AWS account)
aws s3 mb s3://k8s-platform-terraform-state --region eu-west-3
aws s3api put-bucket-versioning \
  --bucket k8s-platform-terraform-state \
  --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name k8s-platform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-3

# 2. Apply shared foundation
cd _core/shared/dev
terraform init && terraform apply

# 3. Apply platform domain
cd ../../../domains/platform/dev
terraform init && terraform apply

# 4. Configure kubectl
aws eks update-kubeconfig --region eu-west-3 --name dev-k8s
```

## Adding a new domain

Domains are scaffolded by platform-bot:

```bash
platform-bot domain add --name data --team data-team
```

This generates `domains/data/{dev,staging,prod}/` with:
- `backend.tf`, `providers.tf`, `variables.tf`
- `shared.tf` — remote_state reference to _core/shared
- `nodegroups.tf`, `irsa.tf`, `outputs.tf` — pre-filled templates

## Local development

```bash
# Install tfenv and use pinned version
tfenv install
tfenv use

# Install pre-commit hooks
pre-commit install

# Format
terraform fmt -recursive

# Lint
tflint --config _ci/.tflint.hcl --chdir _core/shared/dev
```

## Access management

### Developer access — AWS IAM Identity Center

Zero static credentials. Developers authenticate via SSO and assume temporary IAM roles.

```bash
# One-time setup
aws configure sso --profile dev-platform

# Daily workflow
aws sso login --profile dev-platform
export AWS_PROFILE=dev-platform
terraform plan
```

Permission matrix:

| Group                | dev         | staging     | prod        |
|----------------------|-------------|-------------|-------------|
| platform-devs        | poweruser   | readonly    | readonly    |
| platform-maintainers | poweruser   | poweruser   | readonly    |
| CI (GitHub Actions)  | apply       | apply       | apply       |

**Prod apply is CI-only — no human can apply to prod from a local machine.**

Add developers: AWS console → IAM Identity Center → Users → assign to group.
Switch IdP to Okta/Google: configure external IdP + SCIM in IAM Identity Center console — no Terraform changes required.

### CI access — GitHub Actions OIDC

No credentials stored in GitHub. The only GitHub secret is the role ARN.

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_TERRAFORM_ROLE_ARN }}
    aws-region: eu-west-3
```

After first `terraform apply` on `_core/shared`:
```bash
terraform output github_plan_role_arn   # → AWS_TERRAFORM_PLAN_ROLE_ARN
terraform output github_apply_role_arn  # → AWS_TERRAFORM_ROLE_ARN
```

## Compliance

Controls are graduated per environment:

| Control         | dev  | staging | prod |
|-----------------|------|---------|------|
| CloudTrail      | ✓    | ✓       | ✓    |
| KMS CMK         | ✓    | ✓       | ✓    |
| VPC Flow Logs   | ✓    | ✓       | ✓    |
| GuardDuty       | ✗    | ✓       | ✓    |
| AWS Config      | ✗    | ✓       | ✓    |
| Log retention   | 365d | 365d    | 6yr  |

SOC2 Type II: enable all modules in staging + prod, run for 6 months with no findings.
HIPAA: increase `log_retention_days` to 2190 in prod, sign BAA with AWS, isolate PHI namespaces.
