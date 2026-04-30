# PR #39 — Doc-driven review (Sprint 2A — Terraform S3 + IRSA)

**Date**: 2026-04-26
**Reviewer**: Claude Code (doc-driven via Context7)
**PR**: https://github.com/PodYourLife/k8s-Platform/pull/39
**Title**: `feat(terraform/platform/dev): provision QuanvNN datasets S3 bucket and IRSA role`
**Branch**: `feat/quanvnn-platform-infra-tf` → `main`
**Commits in scope**: `0cd31d2` (S3 bucket + 5 companion resources), `b49d647` (IRSA module + outputs)
**Diff**: +117 / -1 lines, 3 files exactly (1 new, 2 modified)
**Provider versions anchored**: `hashicorp/aws` `~> 5.0` (locked `5.100.0`), `hashicorp/tls` `~> 4.0` (locked `4.2.1`)

---

## 1. Overall verdict

**APPROVE** — with two **non-blocking 🟡 notes** for Sprint 2B alignment (Topic F output naming) and future-multi-env reuse (Topic G env hardcoding).

The PR provisions a correctly-secured S3 bucket and an IRSA role with the exact identity-chain subject `system:serviceaccount:ml:quanvnn-sa`. Every doc-checked AWS provider resource shape matches the v5.100.0 reference (most importantly the v4+ mandatory `filter {}` empty block on the lifecycle rule, which would silently fail at apply time if omitted). The IAM policy is least-privilege (read-only S3, scoped to the bucket ARN, no wildcards). The `_core/modules/aws/irsa` deviation from the original prompt is **accepted** — it produces equivalent IAM resources, mirrors the existing `irsa_argocd_image_updater` call site (verified in dev/staging/prod), and reduces duplication.

`terraform fmt -check`, `init -backend=false`, and `validate` all pass independently.

---

## 2. Findings summary

| Topic | Status | Severity (if not ✅) | Action required |
|---|---|---|---|
| A — S3 baseline security | ✅ | — | none |
| B — S3 lifecycle | ✅ | — | none |
| C — IRSA module deviation | ✅ | — | none — deviation accepted |
| D — Trust policy OIDC subject | ✅ | — | none |
| E — Inline policy least privilege | ✅ | — | none |
| F — Outputs naming for 2B | 🔧 | 🟡 (low) | Confirm Sprint 2B placeholder map uses `quanvnn_datasets_bucket_name` (plural) — see §3 F |
| G — Identity chain regression | ✅ + 🟡 | 🟡 (low) | Consider `var.environment` interpolation for bucket name when copying to staging/prod |
| H — Terraform hygiene | ✅ | — | none |

**Counts**: ✅ 6 — 🔧 1 — ❌ 0. Two 🟡 notes (no blockers).

---

## 3. Topic-by-topic detail

### A — S3 baseline security

**Finding**: All four `aws_s3_bucket_public_access_block` booleans are explicitly set to `true`, ownership is `BucketOwnerEnforced` (ACLs disabled — strongest baseline), versioning status is the case-correct `"Enabled"`, and SSE-S3 (`AES256`) is acceptable for `compliance_profile = "none"` (the dev default).

**Evidence**:
- File: `terraform/domains/platform/dev/s3.tf:39-45` — all 4 booleans set to `true` (matches the textbook example below verbatim).
- File: `terraform/domains/platform/dev/s3.tf:48-54` — `object_ownership = "BucketOwnerEnforced"`.
- File: `terraform/domains/platform/dev/s3.tf:21-27` — `versioning_configuration { status = "Enabled" }`.
- File: `terraform/domains/platform/dev/s3.tf:29-37` — SSE-S3 with `sse_algorithm = "AES256"` and `bucket_key_enabled = true`.
- File: `terraform/_core/shared/dev/terraform.tfvars.example:9` — `compliance_profile = "none"` (dev default; no SSE-KMS requirement).
- Doc: Context7 `/hashicorp/terraform-provider-aws/v5.100.0` — *aws_s3_bucket_public_access_block — Argument Reference*, defaults: "block_public_acls — Whether Amazon S3 should block public ACLs … Defaults to `false`." (each of the 4 args defaults to `false`, so they MUST be explicitly set to `true` — the PR does so).
- Doc: Context7 `/hashicorp/terraform-provider-aws/v5.100.0` — *Example Usage of aws_s3_bucket_public_access_block* (textbook example):
  ```terraform
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  ```
  PR snippet is byte-identical.

**Recommended action**: none.

---

### B — S3 lifecycle policy soundness

**Finding**: The lifecycle rule uses the v4+ `aws_s3_bucket_lifecycle_configuration` standalone resource (not the deprecated inline `lifecycle_rule` block on `aws_s3_bucket`), includes the **mandatory** empty `filter {}` block, sets `status = "Enabled"`, has an explicit `id`, and uses `noncurrent_version_expiration.noncurrent_days = 90`.

**Evidence**:
- File: `terraform/domains/platform/dev/s3.tf:56-67` — exact rule shape.
- Doc: Context7 `/hashicorp/terraform-provider-aws/v5.100.0` — *Configure S3 Lifecycle with No Filter*: "This Terraform configuration defines an S3 bucket lifecycle rule that applies to all objects in the bucket by using an empty filter block."
  ```terraform
  rule {
    id = "rule-1"
    filter {}
    status = "Enabled"
  }
  ```
  PR uses the same `filter {}` pattern. Without it, `terraform apply` returns `MalformedXML` from the S3 API.
- Doc: same library, *S3 Lifecycle Noncurrent Version Expiration Configuration* — `noncurrent_days` (Required): "Number of days an object is noncurrent before Amazon S3 can perform the associated action. Must be a positive integer." `90` satisfies this.
- Doc: same library, *S3 Lifecycle Configuration with Versioning* — confirms the `noncurrent_version_expiration { noncurrent_days = 90 }` shape inside a `rule { … status = "Enabled" }` block.

**Recommended action**: none.

---

### C — IRSA module usage vs raw resources (acknowledged deviation)

**Finding**: The author used `module "irsa_quanvnn"` referencing `terraform/_core/modules/aws/irsa`. The module produces equivalent IAM resources to the raw-resource template the original Sprint 2A prompt described. Deviation is **accepted** because it matches the existing project pattern (`irsa_argocd_image_updater` uses the same module in `dev`, `staging`, and `prod`).

**Evidence**:
- File: `terraform/_core/modules/aws/irsa/iam_role.tf:34-39` — produces `aws_iam_role.this` with assume-role policy from a `data.aws_iam_policy_document.trust` (line 10-32).
- File: `terraform/_core/modules/aws/irsa/iam_policy.tf:16-26` — produces `aws_iam_policy.this` (managed policy) + `aws_iam_role_policy_attachment.this`. (Stylistic note: managed policy + attachment, not inline `aws_iam_role_policy` — equivalent IAM behavior, slightly preferable for separate auditability.)
- File: `terraform/_core/modules/aws/irsa/outputs.tf:1-4` — exports `role_arn` (consumed by the new output `quanvnn_irsa_role_arn`).
- File: `terraform/domains/platform/dev/irsa.tf:8-36` (existing) and `:39-69` (new) — same `source = "../../../_core/modules/aws/irsa"` for both call sites.
- Cross-env evidence (`grep -rln 'modules/aws/irsa'`): the module is also called from `terraform/domains/platform/staging/irsa.tf:8` and `terraform/domains/platform/prod/irsa.tf:8` — canonical pattern across all three envs.
- File: `terraform/domains/platform/dev/irsa.tf:42-49` — required inputs all passed:
  - `cluster_oidc_issuer_url = local.cluster_oidc_issuer_url` (sourced from `_core/shared/dev` remote state, see `shared.tf:20` and `_core/shared/dev/outputs.tf:54-56`).
  - `namespace = "ml"`.
  - `service_account_name = "quanvnn-sa"` (identity-chain lock).
  - `policy_statements` scoped to bucket ARN via `aws_s3_bucket.quanvnn_datasets.arn` (build-time ref, not hardcoded string).
  - `tags = { Environment, Component = "quanvnn", Workload = "ml" }`.
- File: `terraform/domains/platform/dev/irsa.tf:51-62` — only `s3:ListBucket` and `s3:GetObject`; **no** `s3:*`, `s3:PutObject`, `kms:*`, or other leaks.

**Recommended action**: none.

---

### D — IRSA trust policy OIDC subject

**Finding**: The trust policy hardcodes `StringEquals` (not `StringLike`), `:aud = "sts.amazonaws.com"`, `:sub = "system:serviceaccount:ml:quanvnn-sa"`, and `Federated = arn:aws:iam::<account>:oidc-provider/<oidc-issuer>` — exactly matching the AWS EKS IRSA reference doc.

**Evidence**:
- File: `terraform/_core/modules/aws/irsa/iam_role.tf:10-32` — module trust-policy data source:
  - `actions = ["sts:AssumeRoleWithWebIdentity"]` (line 13).
  - `principals.identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer}"]` (line 17).
  - `condition.test = "StringEquals"` (line 21 and 27 — both conditions, no `StringLike`).
  - `condition.variable = "${local.oidc_issuer}:sub"`, `values = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]` (line 22-23).
  - `condition.variable = "${local.oidc_issuer}:aud"`, `values = ["sts.amazonaws.com"]` (line 28-29).
- File: `terraform/_core/modules/aws/irsa/iam_role.tf:6-8` — `local.oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")` (correctly strips the `https://` so the condition variable matches the AWS-side condition key format `oidc.eks.<region>.amazonaws.com/id/<id>:sub`).
- Caller resolves to: `namespace = "ml"`, `service_account_name = "quanvnn-sa"` → `:sub` = `system:serviceaccount:ml:quanvnn-sa` (verbatim required string).
- Doc: Context7 `/awsdocs/amazon-eks-user-guide` — *Trust Policy for Account A's Role (OIDC Federation)*:
  ```json
  "Condition": {
    "StringEquals": {
      "oidc.eks.region-code.amazonaws.com/id/EXAMPLE:aud": "sts.amazonaws.com",
      "oidc.eks.region-code.amazonaws.com/id/EXAMPLE:sub": "system:serviceaccount:default:my-service-account"
    }
  }
  ```
  Module-rendered policy is structurally byte-identical (substituting the real OIDC issuer ID and the `ml/quanvnn-sa` SA).
- Doc: same library, *Update IAM Trust Policy for EKS Cluster* — verbatim quote: "Ensure the 'Condition' operator is set to 'StringEquals'." ✅

**Recommended action**: none.

**Verification deferred** (post-merge): once `_core/shared/dev/outputs.cluster_oidc_issuer_url` resolves to the actual `oidc.eks.eu-west-3.amazonaws.com/id/<id>` URL after `terraform apply`, run a one-time `aws iam get-role --role-name dev-k8s-quanvnn-role --query 'Role.AssumeRolePolicyDocument'` and confirm the rendered `:sub` is the literal `system:serviceaccount:ml:quanvnn-sa`. (Out of Sprint 2A scope — read-only review.)

---

### E — IAM policy least privilege

**Finding**: Policy grants exactly `s3:ListBucket` on the bucket ARN and `s3:GetObject` on `<arn>/*`. No wildcards. No write/delete/policy-mutation actions. Effect = `Allow`. Bucket ARN is referenced via `aws_s3_bucket.quanvnn_datasets.arn` (build-time link — refactor-safe, no hardcoded string).

**Evidence**:
- File: `terraform/domains/platform/dev/irsa.tf:51-62` — verbatim:
  ```terraform
  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.quanvnn_datasets.arn]
    },
    {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.quanvnn_datasets.arn}/*"]
    },
  ]
  ```
- File: `terraform/_core/modules/aws/irsa/iam_policy.tf:4-14` — confirms the `dynamic "statement"` correctly forwards `effect`, `actions`, `resources` into the rendered `aws_iam_policy_document`.
- E1 (resource scoping): both statements reference `aws_s3_bucket.quanvnn_datasets.arn` — never `"*"`.
- E2 (no wildcards): grep on the diff shows no `"s3:*"`, no `Resource: "*"`.
- E3 (no write actions): no `s3:PutObject`, `s3:DeleteObject`, `s3:PutBucketPolicy`, `s3:PutBucketAcl`, `kms:*`.
- E4 (Effect Allow): both statements explicit `effect = "Allow"`.

**Recommended action**: none.

---

### F — Outputs naming for Sprint 2B

**Finding**: Three outputs added with clear `description`, no `sensitive = true`. Names match the audit-derived expectation for the IRSA role ARN exactly. Bucket-name output uses **plural `datasets`** (matching the resource name and bucket name `podyourlife-quanvnn-datasets-dev`), whereas the prompt's audit reference cited a singular `quanvnn_dataset_bucket`. Sprint 2B placeholder map should be aligned to the actual output name to avoid a round-trip rename.

**Evidence**:
- File: `terraform/domains/platform/dev/outputs.tf:19-32` — three outputs, all alphabetically ordered (after `node_group_*`):
  - `quanvnn_datasets_bucket_arn` — description: "ARN of the QuanvNN datasets S3 bucket".
  - `quanvnn_datasets_bucket_name` — description: "Name of the QuanvNN datasets S3 bucket".
  - `quanvnn_irsa_role_arn` — description: "IRSA role ARN for the QuanvNN ServiceAccount (ml/quanvnn-sa) — read-only S3 access".
- F1: name comparison against original audit expectation:
  - `quanvnn_irsa_role_arn` ↔ audit `quanvnn_irsa_role_arn` → **exact match** ✅.
  - `quanvnn_datasets_bucket_name` ↔ audit `quanvnn_dataset_bucket` → **near-match** (plural `datasets` vs singular `dataset`, and `_bucket_name` vs `_bucket`). 🟡 minor.
- F2: each output has a non-empty description ✅.
- F3: no `sensitive = true` on any of the three (correct — bucket name and role ARN are not secrets and must be readable for hydration) ✅.

**Recommended action** (🔧 🟡 low):
- Option A (preferred): keep PR #39 as-is, and align the Sprint 2B platform-bot placeholder map to use:
  - `__QUANVNN_IRSA_ROLE_ARN__` ← `quanvnn_irsa_role_arn`
  - `__QUANVNN_DATASETS_BUCKET__` ← `quanvnn_datasets_bucket_name`
  - (Optional) `__QUANVNN_DATASETS_BUCKET_ARN__` ← `quanvnn_datasets_bucket_arn` (only if any consumer needs the ARN form).
- Option B: rename outputs to singular `quanvnn_dataset_bucket{_name,_arn}` if the audit's singular form is the locked contract. Requires one-line edits to `outputs.tf` and a follow-up commit on this branch.

Either option resolves the discrepancy. Pick before Sprint 2B starts, not after.

---

### G — Identity chain regression check

**Finding**: SA name (`quanvnn-sa`) and namespace (`ml`) are exact matches to the audit's locked contract. Bucket name `podyourlife-quanvnn-datasets-dev` follows the `podyourlife-quanvnn-datasets-<env>` pattern with `dev` hardcoded as a literal — tolerable for `domains/platform/dev/` scope but creates copy-paste duplication when the file is mirrored to staging/prod.

**Evidence**:
- File: `terraform/domains/platform/dev/irsa.tf:45` — `namespace = "ml"` (literal string).
- File: `terraform/domains/platform/dev/irsa.tf:46` — `service_account_name = "quanvnn-sa"` (literal string).
- File: `terraform/domains/platform/dev/s3.tf:10` — `bucket = "podyourlife-quanvnn-datasets-dev"` (literal `dev`, not `var.environment`).
- File: `terraform/domains/platform/dev/variables.tf` — `var.environment` is declared with default `"dev"` (verified in Sprint 2A discovery).

G1: ✅ — `quanvnn-sa` exact.
G2: ✅ — `ml` exact.
G3: ⚠️ — env-string is duplicated (literal `"dev"` in bucket name + already implicit in the directory path). Consider:
```terraform
bucket = "podyourlife-quanvnn-datasets-${var.environment}"
```
This makes the file copy-safe for `domains/platform/{staging,prod}/` and removes the divergence risk where someone copies the file but forgets to update the bucket name string.

**Recommended action** (🟡 low): consider the `${var.environment}` interpolation for the bucket name. Not a blocker — staging/prod don't exist yet for this domain, and the literal can be flipped at copy-paste time. Flag it now to avoid a future "I copied the file and forgot to rename" incident.

---

### H — Terraform hygiene

**Finding**: All hygiene checks pass.

**Evidence**:
- H1: `terraform fmt -check -recursive` exit code 0, no diff (verified at Step 2).
- H2: `terraform/domains/platform/dev/versions.tf:9-12` — `aws = { source = "hashicorp/aws", version = "~> 5.0" }`. Lock file `.terraform.lock.hcl` pins `5.100.0`. TLS provider also pinned `~> 4.0` / `4.2.1`. `terraform { required_version = ">= 1.6.0" }` (line 6).
- H3: no new providers in the diff. The only module source introduced is `../../../_core/modules/aws/irsa` (already used by `irsa_argocd_image_updater`, no new external registry dependency).
- H4: resource and module names follow snake_case (`quanvnn_datasets`, `irsa_quanvnn`) — consistent with `irsa_argocd_image_updater` and `node_groups` in the same domain.
- H5: no hardcoded AWS account ID in the diff. Bucket name does not embed an account ID. The `account_id` used for the OIDC provider ARN comes from `data.aws_caller_identity.current.account_id` inside the module (build-time provider context).

**Recommended action**: none.

---

## 4. Cross-cutting observations

### Items already covered by AUDIT_QUANVNN_MVP.md (not re-audited)

The prompt references `AUDIT_QUANVNN_MVP.md` as the prior static audit. **This file is not present at the repo root** (`ls /Users/jackmaarek/DEV/PodYourLife/k8s-platform/AUDIT_QUANVNN_MVP.md` → not found). PR_38_REVIEW.md is the only prior review document at the root.

This review therefore does not assume any prior audit findings and re-evaluates the PR strictly against AWS provider v5.100.0 docs, the AWS EKS IRSA reference, and the project's own existing patterns.

If `AUDIT_QUANVNN_MVP.md` is expected to be at a different path or in a sibling repo (e.g. `QuanvNN_MVP/`), the assumption stands; in that case Sprint 2B/2C scope items mentioned in the audit are out of this review's scope by design.

### New items surfaced by this doc-driven review

1. **Output name discrepancy (Topic F)** — `quanvnn_datasets_bucket_name` vs the original audit's `quanvnn_dataset_bucket`. Resolved by aligning the Sprint 2B placeholder map (preferred) or renaming the output (optional).
2. **Env literal in bucket name (Topic G)** — minor copy-paste hazard for future staging/prod expansion. Single-line fix.

### Pattern deviation verdict (raw resources vs `_core/modules/aws/irsa`)

**Accepted.** The module produces functionally equivalent IAM resources (1× IAM role with OIDC trust policy + 1× managed IAM policy + 1× role-policy attachment) and is the canonical pattern across `domains/platform/{dev,staging,prod}` for the existing `irsa_argocd_image_updater`. Using raw resources would have introduced ~30 lines of duplicated boilerplate for the same IAM behavior. The module's signature also enforces correct OIDC condition shape (`StringEquals`, `:sub`, `:aud`) — fewer chances for the most common IRSA bug source (typo'd condition operator or sub format).

---

## 5. Notes for Sprint 2B / 2C

These items affect downstream work but are NOT blockers for PR #39 merge.

### Sprint 2B — placeholder mapping in platform-bot

Confirmed output names available for the Go placeholder map:
- `quanvnn_irsa_role_arn` → `__QUANVNN_IRSA_ROLE_ARN__` (typically used as the `eks.amazonaws.com/role-arn` SA annotation in `kubernetes/helm/values/quanvnn-dev.yaml`).
- `quanvnn_datasets_bucket_name` → `__QUANVNN_DATASETS_BUCKET__` (typically used as a `S3_DATASETS_BUCKET` env var in the Job container).
- `quanvnn_datasets_bucket_arn` → `__QUANVNN_DATASETS_BUCKET_ARN__` (only if any downstream consumer needs the ARN form; otherwise omit).

The bot's hydration step should read these via `terraform output -json` against the `domains/platform/dev` state once the apply has run.

### Sprint 2C — Kubernetes manifests

Nothing in PR #39 blocks Sprint 2C. The chart's `serviceAccount.irsaRoleArn` Helm value will receive `__QUANVNN_IRSA_ROLE_ARN__` at hydration time. The chart's `config.S3_DATASETS_BUCKET` env var will receive `__QUANVNN_DATASETS_BUCKET__`. ESO + Kyverno work on the `ml` namespace can proceed in parallel — they do not depend on this PR's outputs.

### Verification gates (post-apply, out of Sprint 2A scope)

- [ ] After `platform-bot env apply --env dev`: confirm bucket `podyourlife-quanvnn-datasets-dev` exists in `eu-west-3` with versioning Enabled, public access fully blocked, lifecycle rule `expire-noncurrent-versions` Enabled.
- [ ] After apply: `aws iam get-role --role-name dev-k8s-quanvnn-role --query 'Role.AssumeRolePolicyDocument'` → confirm `:sub` equals `system:serviceaccount:ml:quanvnn-sa` (literal).
- [ ] After Sprint 3 chart deploy: pod logs show successful `s3:ListBucket` against `podyourlife-quanvnn-datasets-dev` from inside the cluster (proves the IRSA chain).

---

## Appendix — Local validation output (verbatim)

```
$ cd terraform/domains/platform/dev
$ terraform fmt -check -recursive
(no output, exit code 0)

$ terraform init -backend=false 2>&1 | tail -10
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/tls v4.2.1...
- Installed hashicorp/tls v4.2.1 (signed by HashiCorp)
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has been successfully initialized!

$ terraform validate
Success! The configuration is valid.
```

## Appendix — Context7 lookups performed

| # | Library ID | Topic |
|---|---|---|
| 1 | `/hashicorp/terraform-provider-aws/v5.100.0` | S3 lifecycle `filter {}` requirement, `noncurrent_version_expiration`, `status` |
| 2 | `/hashicorp/terraform-provider-aws/v5.100.0` | `aws_s3_bucket_public_access_block` defaults, `BucketOwnerEnforced`, SSE valid algorithms |
| 3 | `/awsdocs/amazon-eks-user-guide` | IRSA trust policy `StringEquals`, `:sub`, `:aud`, Federated principal |

Plus 2 `resolve-library-id` calls (AWS provider + Amazon EKS User Guide).
