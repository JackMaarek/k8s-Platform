# CLAUDE.md — k8s-platform

Context file for Claude Code. Read this before touching any file in this repo.

## What this repo is

`k8s-platform` is a **GitOps-first Kubernetes platform template** for PodYourLife.
It is consumed by `platform-bot` (a Go CLI) which clones `main`, resolves placeholders
via `env hydrate`, and commits to environment branches (`dev`, `staging`, `prod`).

**This repo must stay purely declarative — no shell scripts, no imperative logic.**

---

## Critical syntax distinction

Two placeholder syntaxes coexist. **Never conflate them.**

| Syntax | Owner | Lifecycle |
|--------|-------|-----------|
| `__SNAKE_CASE__` | platform-bot | Replaced at `env hydrate` time, before commit to env branch |
| `{{.camelCase}}` | ArgoCD goTemplate | Evaluated at ArgoCD runtime by ApplicationSet generators |

Example of correct coexistence in an ApplicationSet:
```yaml
generators:
  - list:
      elements:
        - env: __ENV__                    # ← replaced by platform-bot
          targetRevision: __TARGET_REVISION__
template:
  metadata:
    name: 'prometheus-{{.env}}'          # ← evaluated by ArgoCD at runtime
```

---

## Branch model

```
main      ←  __PLACEHOLDER__ values only — this is the template. Never deployed directly.
dev       ←  platform-bot managed — ArgoCD watches this branch
staging   ←  platform-bot managed — ArgoCD watches this branch
prod      ←  platform-bot managed — ArgoCD watches this branch
feat/*    ←  all feature work here, PR → main
fix/*     ←  all fixes here, PR → main
```

Rules:
- Features are always branched from `main` (placeholders), never from env branches
- Env branches are produced by `platform-bot`, never edited directly
- Cherry-pick main → env is never needed: `platform-bot env hydrate` re-resolves from main
- After merging `feat/*` → `main`: checkout env branch, merge main, then run `env hydrate`
- Claude should always produce files with `__PLACEHOLDER__` syntax for values that
  differ between environments. Never hardcode `eu-west-3`, `dev`, account IDs, etc.

---

## File rules (strictly enforced)

1. **Max 200 lines per file** — split if needed
2. **One responsibility per file** — values files own one component, manifests own one resource type
3. **Never delete comments** — only modify if the file is already being changed for another reason
4. **Patches are line-by-line** — no wholesale rewrites unless explicitly requested
5. **Announce changes before making them**
6. **`git add` file by file** — never `git add .` or `git add -A`
7. **`.gitignore`, `README`, bootstrap files** — treat as sensitive, extra caution required

---

## platform.yaml

Source of truth for platform component versions and per-env state.

```yaml
versions:                     # certified component versions (global defaults)
  kubernetes: "1.33"          # consumed by bot for Kind + tfvars
  istio: "1.27.1"            # consumed by bot → __ISTIO_VERSION__ in ApplicationSets
  argocd: "7.8.26"           # consumed by bot only (helm install --version), NOT in ApplicationSets
  prometheus: "82.4.2"       # → __PROMETHEUS_VERSION__
  loki: "6.53.0"             # → __LOKI_VERSION__
  promtail: "6.17.1"         # → __PROMTAIL_VERSION__
  kyverno: "3.4.1"           # → __KYVERNO_VERSION__
  external_secrets: "0.10.7" # → __EXTERNAL_SECRETS_VERSION__
  opencost: "1.42.0"         # → __OPENCOST_VERSION__
  cert_manager: "v1.20.0"    # → __CERT_MANAGER_VERSION__

environments:                 # per-env resolved state, written by platform-bot env setup
  dev:
    region: eu-west-3
    account_id: ""            # populated by env setup
    cluster_name: ""
    eso_irsa_role_arn: ""
    target_revision: dev
    repo_url: ""
    # kubernetes: "1.32"      # optional per-env override
    # istio: "1.26.4"         # optional per-env override
```

**No `grafana` in versions** — Grafana is a subchart of `kube-prometheus-stack`, versioned implicitly via `prometheus`.
**No `enabled` flag** — removed, was never consumed.

---

## Architecture

### Terraform state flow (strict ordering)
```
domains/organization   →  IAM Identity Center (one-time, management account)
_core/shared/{env}     →  VPC, EKS, OIDC, IRSA, CI access (GitHub OIDC)
domains/platform/{env} →  nodegroups, addons (reads _core state)
```

`domains/organization` manages all env account assignments from a single root.
`backend.tf` files are **generated from `backend.tf.template`** by platform-bot.
Terraform `backend {}` blocks cannot use variables — this is intentional.

### Terraform tfvars on main

All `terraform.tfvars` on `main` contain only `__PLACEHOLDER__` tokens (exception:
`environment`, `compliance_profile`, and `log_retention_days` which are static per-env defaults).
The gitignore rule `!terraform/**/*.tfvars` allows committing them.

GitHub OIDC uses `allowed_repos` (list of repo names, zero-trust) instead of `github_repo` (single string).
The module `github-oidc` accepts `allowed_repos` + `apply_branch_pattern`.

### ArgoCD sync waves (actual values from repo)

```
wave -3   namespaces
wave -2   istio-base (CRDs)
wave -1   istiod (control plane)
wave  0   istio-cni
wave  1   external-secrets
wave  2   istio-gateway
wave  3   istio-security
wave  4   istio-telemetry
wave  5   istio-mesh-config
wave  6   promtail
wave  7   loki
wave  8   prometheus (kube-prometheus-stack + grafana subchart)
wave  9   grafana-datasources
wave 10   grafana-dashboards
wave 11   servicemonitors (argocd, monitoring, development)
wave 12   kyverno
wave 13   kyverno-policies
wave 14   opencost
wave 15   cert-manager
wave 16   cert-manager-issuer
```

### Chart versions in ApplicationSets

All `targetRevision` values for Helm charts are `__PLACEHOLDER__` tokens on `main`,
resolved by `platform-bot env hydrate` from `platform.yaml → versions`.

| Component | Placeholder | Chart repo |
|-----------|------------|------------|
| Istio (base, cni, istiod, gateway) | `__ISTIO_VERSION__` | `istio-release.storage.googleapis.com/charts` |
| Kyverno | `__KYVERNO_VERSION__` | `kyverno.github.io/kyverno/` |
| External Secrets | `__EXTERNAL_SECRETS_VERSION__` | `charts.external-secrets.io` |
| Prometheus | `__PROMETHEUS_VERSION__` | `prometheus-community.github.io/helm-charts` |
| Loki | `__LOKI_VERSION__` | `grafana.github.io/helm-charts` |
| Promtail | `__PROMTAIL_VERSION__` | `grafana.github.io/helm-charts` |
| OpenCost | `__OPENCOST_VERSION__` | `opencost.github.io/opencost-helm-chart` |
| cert-manager | `__CERT_MANAGER_VERSION__` | `charts.jetstack.io` |

**ArgoCD is NOT in this table** — it is installed by `platform-bot local up` via `helm install --version`,
not via an ApplicationSet. Its version lives in `platform.yaml → versions.argocd` only.

### Grafana datasource architecture
- **Chart generates**: Prometheus + Alertmanager datasource ConfigMap (native)
- **Our ConfigMaps**: one per datasource in `kubernetes/manifests/monitoring/datasources/`
- **`defaultDatasourceEnabled: false`** in `grafana-values.yaml` disables the chart-generated one
- **Sidecar**: `grafana_datasource=1` label, watches our ConfigMaps only
- **Never define datasources in both places** — dual provisioning crashes Grafana on boot

### Monitoring values split (SRP)
```
prometheus-values.yaml  →  metrics collection (operator, prometheus, alertmanager, exporters)
grafana-values.yaml     →  visualization (grafana subchart, sidecar, persistence)
```
Both are passed as `valueFiles` in the prometheus ApplicationSet. ArgoCD merges them.

### mTLS
- STRICT mode across all namespaces with `istio-injection: enabled`
- `PeerAuthentication` exceptions in `argocd/platform/istio/security.yaml` cover disabled namespaces

| Namespace | `istio-injection` | Reason |
|-----------|------------------|--------|
| `development` / `staging` / `production` | `enabled` | workload mesh |
| `argocd` | `enabled` | Deployments only, no Jobs |
| `istio-ingress` | `enabled` | gateway pod needs webhook injection (`image: auto`) |
| `monitoring` | `disabled` | Prometheus Jobs cannot Complete with sidecar |
| `istio-system` | `disabled` | Circular dependency — istiod cannot depend on itself |
| `kyverno` | `disabled` | Cleanup CronJobs cannot Complete with sidecar |
| `external-secrets` | `disabled` | istio-init violates PSS restricted (NET_ADMIN, runAsUser=0) |
| `finops` | `enabled` | Deployments only, no Jobs — mTLS for OpenCost ↔ Prometheus |
| `cert-manager` | `disabled` | CRD controller — no mesh traffic needed |

---

## platform-bot commands

| Command | Purpose |
|---|---|
| `init` | Clone k8s-platform, configure remotes, install CI workflows, optionally bootstrap AWS state |
| `bootstrap aws` | Create S3 state bucket + DynamoDB lock table (idempotent, standalone) |
| `env init --env <env>` | Hydrate worktree from main + create env branch (refuses if branch exists) |
| `env hydrate --env <env>` | Re-resolve placeholders on existing branch worktree (idempotent) |
| `env plan --env <env>` | terraform plan on both layers, human-readable summary |
| `env commit --env <env>` | Stage and commit changes on env branch |
| `env push --env <env>` | Push env branch to origin |
| `env apply --env <env>` | terraform apply (dev: local, staging/prod: CI dispatch) |
| `env setup --env <env>` | Guided orchestrator: init → hydrate → plan → commit → push → apply |
| `check` | Verify prerequisites (git, terraform, kubectl, helm, docker, kind) |
| `local up --env <env>` | Create Kind cluster + install platform stack |
| `local down` | Destroy Kind cluster |

### Placeholder tokens resolved by `env hydrate`

Tokens in `*.tfvars`, `*.yaml`, `*.template` files:

| Token | Source | Target files |
|---|---|---|
| `__ENV__` | --env flag | *.tfvars, *.yaml |
| `__TARGET_REVISION__` | env name | *.yaml (ArgoCD) |
| `__AWS_REGION__` | prompt or platform.yaml | *.tfvars, *.yaml |
| `__AWS_ACCOUNT_ID__` | prompt | *.tfvars |
| `__AWS_ACCOUNT_ID_DEV/STAGING/PROD__` | prompt per env | domains/organization/terraform.tfvars |
| `__CLUSTER_NAME__` | derived: {env}-k8s | *.tfvars, *.yaml |
| `__STATE_BUCKET__` | derived from account_id | *.tfvars |
| `__ESO_IRSA_ROLE_ARN__` | post-apply reinjection | *.yaml |
| `__REPO_URL__` | git remote origin | *.yaml (ArgoCD) |
| `__GITHUB_ORG__` | prompt | *.tfvars |
| `__ALLOWED_REPOS__` | prompt (single repo MVP) | *.tfvars |
| `__KUBERNETES_VERSION__` | platform.yaml versions | *.tfvars |
| `__ISTIO_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__PROMETHEUS_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__LOKI_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__PROMTAIL_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__KYVERNO_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__EXTERNAL_SECRETS_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__OPENCOST_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |
| `__CERT_MANAGER_VERSION__` | platform.yaml versions | *.yaml (ArgoCD) |

Tokens consumed only by the bot (NOT in k8s-platform files):
- `__ARGOCD_VERSION__` — used by `helm install --version` in platform-bot only

Placeholders are ONLY allowed in: `*.tfvars`, `*.tfvars.example`, `*.template`, `*.yaml`
Placeholders are FORBIDDEN in `*.tf` files.

---

## Known issues / resolved gotchas

| Issue | Root cause | Fix |
|-------|-----------|-----|
| `ErrImagePull` on `istio-ingressgateway` | Mutating webhook injects sidecar into the gateway itself | `sidecar.istio.io/inject: "false"` in gateway Helm values |
| `ImagePullBackOff` on `kyverno-clean-reports` | `bitnami/kubectl:1.32.3` removed from docker.io | Override to `ghcr.io/kyverno/kyverno-cli:v1.13.4` via `helm.values` |
| Grafana crash `NOT NULL constraint` | Dual datasource provisioning | `defaultDatasourceEnabled: false` + one ConfigMap per datasource |
| ArgoCD dashboard shows no metrics | ServiceMonitor wrong selectors | Correct selectors: `argocd-application-controller`, `argocd-server`, `argocd-repo-server` |
| Placeholders leaked to `main` | `git rebase dev → main` | Always `cherry-pick` commits to `main`, never rebase env branches |
| `account_id` orphan in shared/dev tfvars | Variable not declared in variables.tf | Removed from tfvars, replaced by `aws_account_id` (declared) |
| `istiod.yaml` duplicate `global:` block | Copy-paste error | Removed first duplicate, kept single `global:` block |
| Hardcoded versions in ApplicationSets | Manual version management | Replaced with `__VERSION__` placeholders resolved from platform.yaml |

---

## Session end format

Every session ends with:
- A conventional commit message covering all changes
- One commit per domain touched
- Conventional commits format: `fix(scope): clear explanation of what changed and why`
- Scope mirrors the directory: `terraform/shared`, `terraform/organization`,
  `terraform/modules`, `gitops`, `cmd`, etc.
- Never `Co-authored-by: Claude`

# Git commit rules
- Never add Co-authored-by, Signed-off-by, or any trailer referencing Claude or Anthropic in commit messages
- The only author on commits is the developer who runs the command