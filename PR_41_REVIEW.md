# PR #41 — Doc-Driven Independent Review

**PR**: feat(platform): k8s manifests for QuanvNN MVP (Sprint 2C)
**URL**: https://github.com/PodYourLife/k8s-Platform/pull/41
**Branch**: `feat/quanvnn-platform-infra-k8s` → `main`
**Commits in scope**: `7345510`, `94697b7`, `0d02210`, `0ec75cf`, `a4d5980`
**Diff size**: +239 / −5 across 10 files
**Reviewer**: independent doc-driven pass (Context7 + repo cross-reads)
**Date**: 2026-04-26

---

## Verdict — **REQUEST_CHANGES**

Two BLOCKERS in the `platform` AppProject scoping prevent both new ApplicationSets
(`nvidia-device-plugin`, `priority-classes`) from ever syncing successfully. Both are
silent at chart-render time and only surface when ArgoCD reconciles, so neither
`helm template` nor YAML lint catches them. They must be fixed in this PR (or a
companion PR merged before this one) for Sprint 2C to actually land.

The chart-only changes (C1, C5) and the Kyverno change (C4) are sound and could
ship as-is.

---

## Findings summary

| ID  | Sev      | Topic | One-line                                                                                                |
|-----|----------|-------|----------------------------------------------------------------------------------------------------------|
| F1  | BLOCKER  | H     | `platform.sourceRepos` does not include `https://nvidia.github.io/k8s-device-plugin` — AS will be denied |
| F2  | BLOCKER  | H     | `platform.clusterResourceWhitelist` does not include `scheduling.k8s.io/PriorityClass`                  |
| F3  | HIGH     | I     | Bot's `placeholders.go` does not map `__NVIDIA_DEVICE_PLUGIN_VERSION__` — AS unsyncable until Sprint 2D |
| F4  | MEDIUM   | C     | Kyverno `NotEquals` with `value: "ghcr.io/.../*"` is **pre-existing** literal-string comparison — wildcards do not glob; the new line inherits the same questionable semantics |
| F5  | MEDIUM   | A     | NVIDIA chart values are minimal; `runtimeClassName` choice is correct for EKS GPU AMI but `gpuFeatureDiscovery`/`config.name` aren't pinned, leaving room for future drift |
| F6  | LOW      | D     | ESO `apiVersion: external-secrets.io/v1beta1` is still served in 0.10.7 but the upstream docs now lead with `v1` — flag for Sprint 2D bump |
| F7  | LOW      | B     | NVIDIA AS at wave 2 races `external-secrets` (wave 1) and `istio-gateway` (wave 2); independence is fine but worth documenting |
| F8  | LOW      | E     | PriorityClass values 500/1000 are sound; no `preemptionPolicy` set — defaults to `PreemptLowerPriority`, which the description claims as a feature ("preempts gpu-batch-priority") |
| F9  | INFO     | F     | Identity chain is **non-regressed**: SA template renders `quanvnn-sa` and consumes `__QUANVNN_IRSA_ROLE_ARN__` end-to-end |
| F10 | INFO     | G     | Helm opt-in toggle works correctly; default `enabled: false` renders 0 ExternalSecret; `quanvnn-dev.yaml` opts in at `enabled: true` |

---

## Topic-by-topic detail

### A — NVIDIA k8s-device-plugin chart compatibility

**Files**: `argocd/platform/gpu/nvidia-device-plugin.yaml`, `platform.yaml`

**Cross-checked against**:
- `https://nvidia.github.io/k8s-device-plugin/index.yaml` (chart 0.19.1, latest stable;
  Context7 has no library for this chart so the index.yaml was consulted directly).

**Findings**:
- Chart version `0.19.1` is the latest stable per index.yaml. `kubeVersion: ">= 1.10"`
  in the chart is satisfied by the platform's K8s 1.33.
- `nodeSelector: { node-group: gpu }` matches the label set in
  `terraform/domains/platform` node_groups.gpu.labels (per repo CLAUDE.md). Correct.
- Toleration `nvidia.com/gpu=true:NoSchedule` matches the taint declared on the GPU
  nodegroup (per repo CLAUDE.md). Correct.
- Comment claim "EKS GPU AMIs ship the nvidia container runtime as the default runc
  shim. Setting runtimeClassName would break scheduling on stock AMIs." This is
  **correct for EKS-Optimized Accelerated AMIs** (Bottlerocket and AL2 GPU variants)
  which configure containerd to use `nvidia-container-runtime` as the default OCI
  runtime — the device plugin then needs no runtimeClassName.
- (F5, MEDIUM) The chart exposes `gpuFeatureDiscovery`, `config.name`, `migStrategy`,
  `failOnInitError`, `nfd.enabled` — none are set. Defaults are reasonable for a
  single-tenant g4dn fleet, but pinning `failOnInitError: true` would surface AMI
  misconfiguration faster. Non-blocking.
- The literal placeholder `__NVIDIA_DEVICE_PLUGIN_VERSION__` is only valid AFTER the
  bot's `env hydrate` resolves it. Today the bot does not resolve it (see Topic I).

**Verdict**: chart selection and minimal value set are correct; no changes required
in this PR for Topic A itself.

---

### B — ArgoCD ApplicationSet syntax + `ServerSideApply` + sync-wave timing

**Files**: `argocd/platform/gpu/nvidia-device-plugin.yaml`,
`argocd/platform/gpu/priority-classes.yaml`

**Cross-checked against**: `/argoproj/argo-cd` (Context7), repo CLAUDE.md sync-wave table.

**Findings**:
- Both AS use `goTemplate: true`, list generator, `finalizers`, `syncOptions:
  ServerSideApply=true + CreateNamespace=false`, `syncPolicy.automated.prune+selfHeal`.
  All consistent with the platform's existing AS pattern
  (e.g. `external-secrets/external-secrets.yaml`, `namespaces.yaml`).
- (F7, LOW) `nvidia-device-plugin` is at sync-wave **2**, which collides with
  `istio-gateway` (wave 2 per CLAUDE.md). The two are independent — no resource
  shared, no ordering constraint — so concurrent application is safe. Document
  the choice or move to wave 3 for clarity.
- `priority-classes` at sync-wave **−2** parallels `istio-base` (CRDs, wave −2).
  No inter-dependency; PriorityClass and CRD are independent cluster-scoped
  resources. Comment in the file explains this; correct.
- `ServerSideApply=true` is required because PriorityClass and the device plugin
  DaemonSet both interact with default cluster resources where last-applied
  annotation conflicts can arise. Choice is sound.
- `repoURL: '{{.repoUrl}}'` (camelCase, runtime-evaluated by ArgoCD) on
  `priority-classes` correctly mirrors `namespaces.yaml`. The `__REPO_URL__`
  placeholder feeds the generator element, which then expands `{{.repoUrl}}`.
- `repoURL: https://nvidia.github.io/k8s-device-plugin` on `nvidia-device-plugin`
  is hardcoded (not a placeholder) — same convention as
  `external-secrets/external-secrets.yaml` (`repoURL: https://charts.external-secrets.io`).

**Verdict**: AS structure and syncOptions are sound. F7 is a documentation nit only.

---

### C — Kyverno image-registry allowlist extension

**Files**: `kubernetes/policies/check-image-registry.yaml`

**Cross-checked against**: `/kyverno/kyverno` (Context7) — Condition operator schema.

**Findings**:
- The new `value: "public.ecr.aws/aws-cli/*"` line follows the **existing** repo
  pattern of stacked `NotEquals` conditions inside `deny.conditions.all`.
- (F4, MEDIUM, **PRE-EXISTING**) Per the Kyverno upstream `Condition` schema,
  `NotEquals` is documented as a fixed-value comparison; **wildcard glob support
  is not part of the operator semantics** (wildcards belong to `pattern:` blocks
  with the `?` / `*` syntax, NOT to `Condition.value`). This means every existing
  `value: "<registry>/*"` entry is being compared as a literal string containing
  an asterisk character — every container image is `NotEquals` to that literal,
  so all images fail every condition, and `all` deny would fire on every Pod.
  - The fact that the policy hasn't blocked any pod suggests it is either evaluated
    in `Audit` mode (confirmed: `validationFailureAction: Audit`) AND/OR Kyverno
    has been silently treating the entries as glob patterns despite the docs.
  - **The new line C4 inherits the same questionable construction.** It does not
    make things worse, but the PR is a good moment to flag this.
  - **Recommendation (NOT blocking this PR)**: open a follow-up to migrate the
    policy to either (a) the documented `pattern:` form
    (`image: "ghcr.io/PodYourLife/* | docker.io/library/* | …"`) or (b) the
    `In` operator with explicit array values. Sprint 3 should validate behavior
    against a known-bad pod before flipping `Audit` → `Enforce` in staging.
- Excluded namespaces list is unchanged and remains correct — `external-secrets`
  is excluded, so this allowlist won't block ESO's own pods.

**Verdict**: PR-local change is correct and additive. F4 is a cross-cutting
recommendation, not a blocker.

---

### D — ExternalSecret API version + dockerconfigjson template

**Files**: `kubernetes/helm/ml-batch-job/templates/external-secret.yaml`,
`kubernetes/helm/ml-batch-job/values.yaml`,
`kubernetes/helm/ml-batch-job/values.schema.json`

**Cross-checked against**: `/external-secrets/external-secrets` (Context7),
`kubernetes/manifests/secrets/grafana-admin-externalsecret.yaml`.

**Findings**:
- `apiVersion: external-secrets.io/v1beta1` matches the existing
  `grafana-admin-externalsecret.yaml` and is **still served in ESO 0.10.7**.
- (F6, LOW) Upstream docs now lead with `external-secrets.io/v1` (GA in 0.10).
  v1beta1 remains served for backward compatibility but is the legacy version.
  Fixing the new file alone would create inconsistency with grafana — recommend
  migrating both files in a single Sprint 2D follow-up, not in this PR.
- `template.type: kubernetes.io/dockerconfigjson` + `data: { .dockerconfigjson:
  literal {{ .dockerconfig | toString }} }` is the documented pattern for ESO to
  produce a Docker config Secret. Correct.
- The Helm escape `{{ `{{ .dockerconfig | toString }}` }}` correctly produces
  the literal `{{ .dockerconfig | toString }}` in the rendered manifest, which
  ESO then evaluates server-side. PR body confirms this was verified by
  `helm template`.
- `creationPolicy: Owner` + `deletionPolicy: Retain` is conservative and correct
  for an imagePullSecret — ESO owns the lifecycle but won't delete the secret
  if the ExternalSecret is deleted (avoids ImagePullBackOff during chart
  re-installs).
- `secretStoreRef.name: aws-secrets-manager` matches the canonical name pinned
  in the global CLAUDE.md ("`ClusterSecretStore` is always named
  `aws-secrets-manager`"). Correct.
- `quanvnn-dev.yaml` line 53 sets `awsSecretPath: "platform/ghcr-pull-token"`
  (no `__ENV__` segment), unlike `grafana-admin-externalsecret.yaml` line 27
  which uses `platform/__ENV__/grafana-admin`. The PR body acknowledges this
  is the existing chart's value and not part of this PR. **Operator action**:
  before `bootstrap eks --env dev`, seed AWS SM at exactly
  `platform/ghcr-pull-token` (or migrate the value to env-scoped path).

**Verdict**: Correct. F6 is a Sprint 2D concern.

---

### E — PriorityClass values + globalDefault + preemption

**Files**: `kubernetes/manifests/priority-classes/gpu-high-priority.yaml`,
`kubernetes/manifests/priority-classes/gpu-batch-priority.yaml`

**Findings**:
- `value: 1000` (high) and `value: 500` (batch) sit above the implicit default 0
  and well below `system-cluster-critical` (2,000,000,000) and
  `system-node-critical` (2,000,001,000). Choice is sane.
- `globalDefault: false` on both — correct; a `globalDefault: true` would
  retroactively re-prioritize every existing pod without a class, which would
  cascade across the cluster.
- (F8, LOW) Neither file sets `preemptionPolicy`. K8s defaults to
  `PreemptLowerPriority`, which is what the descriptions claim
  ("Preempts gpu-batch-priority"). Defaulting is fine; explicitly setting
  `preemptionPolicy: PreemptLowerPriority` on `gpu-high-priority` would make
  the contract self-documenting. Non-blocking.
- Custom labels `platform.podyourlife.io/domain: ml` and `priority-tier: high|batch`
  are good hygiene — allows future kubectl filtering.
- These manifests are NEVER consumed by any pod template in this PR
  (no `priorityClassName: gpu-batch-priority` is added to `job-cpu.yaml` /
  `job-gpu.yaml`). That's deliberate — Sprint 3 will wire it in. Worth flagging
  in the PR body so reviewers don't expect a chart change.

**Verdict**: Correct. F8 is a polish suggestion.

---

### F — Identity chain non-regression (audit §6)

**Files**: `kubernetes/helm/values/quanvnn-dev.yaml`,
`kubernetes/helm/ml-batch-job/templates/service-account.yaml` (read-only),
`kubernetes/helm/ml-batch-job/templates/job-cpu.yaml` (read-only),
`kubernetes/helm/ml-batch-job/templates/job-gpu.yaml` (read-only),
`kubernetes/helm/ml-batch-job/templates/_helpers.tpl` (read-only),
`platform-bot/internal/gitops/placeholders.go` (read-only, cross-repo).

**Findings**:
- `service-account.yaml` exists and renders:
  - `metadata.name: {{ include "ml-batch-job.serviceAccountName" . }}` — resolves
    to `<release>-quanvnn-sa` when `serviceAccount.name` is empty (it is in
    `quanvnn-dev.yaml`). With release name `quanvnn`, the helper's contains-check
    truncates the duplication and yields `quanvnn-sa`. Verified by reading
    `_helpers.tpl` lines 18-29 + 65-71.
  - `annotations.eks.amazonaws.com/role-arn: {{ .Values.serviceAccount.irsaRoleArn |
    quote }}` — consumes the renamed token `__QUANVNN_IRSA_ROLE_ARN__`.
- `job-cpu.yaml:39` and `job-gpu.yaml:31` both reference
  `serviceAccountName: {{ include "ml-batch-job.serviceAccountName" . }}` —
  same helper, so the same SA name is bound on both pods. Identity chain intact.
- `platform-bot/internal/gitops/placeholders.go:58` already maps
  `"__QUANVNN_IRSA_ROLE_ARN__": pv.QuanvnnIRSARoleARN` (shipped in PR #7,
  ffd16f5). C1 in this PR is the corresponding chart-side rename — they are
  consistent.
- C1's diff is trivially correct: 2 lines, comment + value, both updated.

**Verdict (F9, INFO)**: Identity chain is **non-regressed and consistent across the
chart and the bot**. C1 lands cleanly.

---

### G — Helm opt-in toggle for the new ExternalSecret template

**Files**: `kubernetes/helm/ml-batch-job/values.yaml`,
`kubernetes/helm/ml-batch-job/values.schema.json`,
`kubernetes/helm/ml-batch-job/templates/external-secret.yaml`,
`kubernetes/helm/values/quanvnn-dev.yaml`.

**Findings**:
- Default `imagePullSecret.enabled: false` (flipped from `true → false` in C5).
  This is a deliberate, safer default for a generic chart — consumers who
  pre-create the secret externally are unaffected.
- `quanvnn-dev.yaml:51` sets `enabled: true` — opt-in for the QuanvNN deployment.
- Template gate `{{- if .Values.imagePullSecret.enabled -}}` correctly omits
  the entire ExternalSecret when disabled. PR body confirms `helm template`
  output: 0 ExternalSecret with chart defaults, 1 when `--set
  imagePullSecret.enabled=true`.
- Schema additions:
  - `secretName.minLength: 1` — sane (used as Secret name; can't be empty).
  - `secretStoreRef.name.minLength: 1` — sane.
  - `secretStoreRef.kind.enum: [ClusterSecretStore, SecretStore]` — matches
    the only valid ESO kinds. Correct.
- One missing schema constraint: `awsSecretPath` has no `minLength` and no
  `pattern`. With `enabled: true` and an empty `awsSecretPath`, `helm template`
  will render `key: ""` and ESO will silently fail at sync time with an opaque
  error. **Suggestion (non-blocking)**: in a follow-up, conditionalize the
  schema so that when `enabled: true`, `awsSecretPath: minLength: 1` is
  required. Out of scope for this PR.

**Verdict (F10, INFO)**: Opt-in toggle is correctly wired. Schema is permissive
but does not block the PR.

---

### H — AppProject scoping (CRITICAL)

**Files**: `argocd/projects/platform.yaml` (read-only, NOT modified by PR),
`argocd/projects/ml.yaml` (read-only, justifies platform-AS choice),
`argocd/platform/gpu/nvidia-device-plugin.yaml`,
`argocd/platform/gpu/priority-classes.yaml`.

**Cross-checked against**: `/argoproj/argo-cd` (Context7) — AppProject `sourceRepos`
and `clusterResourceWhitelist` are **enforced at sync time** by
`argocd-application-controller`. Applications referencing a repoURL or producing
cluster-scoped resources outside the project's allowlist are rejected with
`error: application references repository … not permitted in project …` or
`cluster-scoped resource … is not permitted in project …`.

**Findings**:

- **F1, BLOCKER** — `platform.yaml:15-25` lists 10 source repos. The new
  `nvidia-device-plugin` AS uses
  `repoURL: https://nvidia.github.io/k8s-device-plugin`, which is **NOT** in
  the list. ArgoCD will deny the Application at sync time with:

  > application repo `https://nvidia.github.io/k8s-device-plugin` is not
  > permitted in project 'platform'

  **Required fix (in this PR or a companion PR before merge)**:
  add to `argocd/projects/platform.yaml` under `sourceRepos:`

  ```yaml
      - https://nvidia.github.io/k8s-device-plugin
  ```

- **F2, BLOCKER** — `platform.yaml:62-89` lists the cluster-scoped resource
  whitelist. `scheduling.k8s.io/PriorityClass` is **NOT** present. The new
  `priority-classes` AS produces 2 PriorityClass resources at sync time;
  ArgoCD will deny them with:

  > cluster-scoped resource `PriorityClass.scheduling.k8s.io` is not permitted
  > in project 'platform'

  **Required fix (in this PR or companion)**: add to
  `argocd/projects/platform.yaml` under `clusterResourceWhitelist:`

  ```yaml
      - group: scheduling.k8s.io
        kind: PriorityClass
  ```

- The PR comment in `priority-classes.yaml:11-13` is correct that the resources
  cannot live in the `ml` AppProject (`clusterResourceWhitelist: []` per
  `argocd/projects/ml.yaml:33`). The choice of the `platform` project is right
  — but the project itself needs the corresponding whitelist entry.

- **Why these were missed**: `helm lint` and `helm template` only validate
  rendered Kubernetes manifests; they do NOT cross-check ArgoCD AppProject
  RBAC. There is no pre-merge gate today that catches this. **Recommendation
  for Sprint 2D**: add a CI step that diffs every new AS's `repoURL` against
  the referenced AppProject's `sourceRepos`, and every new manifest's
  cluster-scoped GVK against `clusterResourceWhitelist`.

**Verdict**: F1 + F2 are merge-blocking. The PR cannot deploy on any cluster as
it stands.

---

### I — platform-bot version mapping

**Files**: `platform.yaml` (this PR adds line 23),
`platform-bot/internal/gitops/placeholders.go` (read-only, cross-repo).

**Findings**:

- (F3, HIGH, ACKNOWLEDGED IN PR BODY) `platform.yaml:23` adds
  `nvidia_device_plugin: "0.19.1"` with comment `→ __NVIDIA_DEVICE_PLUGIN_VERSION__
  (Sprint 2D bot mapping pending)`.
- `platform-bot/internal/gitops/placeholders.go:35-46` lists the full version
  token mapping. `__NVIDIA_DEVICE_PLUGIN_VERSION__` is **not present**.
- Today's behavior: the bot's `env hydrate` will leave `targetRevision:
  __NVIDIA_DEVICE_PLUGIN_VERSION__` literal in the env branch, which Helm
  will refuse to install with "invalid version". **The nvidia-device-plugin
  Application will never reach Synced state until the bot ships the mapping.**
- Bot-side change required (separate PR in `platform-bot`):
  1. `internal/domain/placeholders.go` — add field
     `NvidiaDevicePluginVersion string` to `PlaceholderValues`.
  2. `internal/gitops/placeholders.go:46` — add map entry
     `"__NVIDIA_DEVICE_PLUGIN_VERSION__": pv.NvidiaDevicePluginVersion,`.
  3. Wherever `PlaceholderValues` is constructed from `platform.yaml`
     (likely `internal/platform/platform.go` resolver), populate the new field
     from `versions.nvidia_device_plugin`.
  4. Test coverage in `internal/gitops/placeholders_test.go` and
     `internal/domain/placeholders_test.go`.

- This PR's own scope is **k8s-platform only**; the cross-repo gap is correctly
  flagged in the PR body and commit `94697b7` message. **Merging this PR
  before Sprint 2D ships in platform-bot is acceptable** as long as the
  follow-up is tracked, AND as long as F1 + F2 are addressed (otherwise the
  AS would fail for an entirely different reason first).

**Verdict**: F3 is a tracked, acknowledged dependency. Not a merge blocker for
this PR by itself, but operationally the device plugin won't run until both
this PR and the Sprint 2D bot change are merged + a fresh `env hydrate` runs.

---

## Cross-cutting observations

1. **No companion bot PR** is required to land this PR safely IF F1/F2 are
   resolved AND operators accept that the nvidia-device-plugin AS will sit at
   `OutOfSync` (or `Unknown`) until Sprint 2D ships. The priority-classes AS
   would still sync successfully on its own once F2 is fixed, since it does
   not consume any version placeholder.

2. **PR scope discipline is excellent.** No drive-by edits, no terraform/
   touched, no platform-bot changes. The 5 commits are atomic and each
   addresses one Sprint 2C item. This makes review and rollback trivial.

3. **Documentation footprint is heavy** (good): every new ApplicationSet and
   manifest has a header comment explaining the role, sync-wave choice, and
   resource scoping. PriorityClass description fields are also populated.

4. **ml AppProject was correctly left untouched.** The PR author identified
   that PriorityClass cannot live in the chart-owned `ml` project (whose
   `clusterResourceWhitelist` is empty) and routed the AS through `platform`.
   The remaining gap is just that `platform`'s whitelist needs the explicit
   GVK entry.

5. **No regression of the audit §6 identity chain.** The `__IRSA_ROLE_ARN__` →
   `__QUANVNN_IRSA_ROLE_ARN__` rename is consistent with the bot's
   `placeholders.go:58` mapping shipped in platform-bot PR #7.

6. **Pre-existing Kyverno construction (F4) is not introduced here** but the
   PR is a good moment to file a follow-up. Verify in Sprint 3 with a
   deliberately-bad pod against an `Enforce`-mode test cluster before
   promoting the policy to staging/prod.

---

## Required actions before merge

- [ ] **F1**: append `https://nvidia.github.io/k8s-device-plugin` to
      `argocd/projects/platform.yaml` `spec.sourceRepos`. 1-line patch.
- [ ] **F2**: append `{ group: scheduling.k8s.io, kind: PriorityClass }` to
      `argocd/projects/platform.yaml` `spec.clusterResourceWhitelist`.
      2-line patch.
- [ ] (Optional but recommended) Update PR body to mention F1/F2 as new sub-
      tasks added during review; cite this report.

---

## Suggested follow-ups (separate PRs)

| Owner | Repo | Action | Trigger |
|---|---|---|---|
| platform-bot | `platform-bot` | Add `__NVIDIA_DEVICE_PLUGIN_VERSION__` mapping + `PlaceholderValues.NvidiaDevicePluginVersion` field + tests | Sprint 2D, before next `env hydrate` on dev |
| platform | `k8s-platform` | Migrate `check-image-registry.yaml` from `NotEquals + value: "*"` to `pattern:` block or `In` operator with literal array; validate with chainsaw test | Sprint 3 (before flipping policy to `Enforce`) |
| platform | `k8s-platform` | Migrate ESO ExternalSecrets from `external-secrets.io/v1beta1` to `v1` (consistent across `grafana-admin-externalsecret.yaml` AND new `external-secret.yaml`) | Sprint 2D |
| platform | `k8s-platform` | Tighten `values.schema.json` so `imagePullSecret.awsSecretPath` requires `minLength: 1` when `enabled: true` (conditional schema via `if/then`) | Sprint 2D |
| platform | `k8s-platform` | Add CI gate that diffs every new AS's `repoURL` against the referenced AppProject's `sourceRepos`, and cluster-scoped GVKs against `clusterResourceWhitelist` | Sprint 3 |
| operator | AWS SM | Seed `platform/ghcr-pull-token` with JSON `{"dockerconfig": "<base64-dockerconfigjson>"}` before `bootstrap eks --env dev` | Before next env setup |
| platform | `k8s-platform` | Sprint 3 chart change: add `priorityClassName: gpu-batch-priority` (default) and override to `gpu-high-priority` for inference workloads in `quanvnn-dev.yaml` | Sprint 3 |

---

## Files examined (and not modified by this PR)

- `argocd/projects/platform.yaml` — surfaced F1 + F2.
- `argocd/projects/ml.yaml` — confirmed PriorityClass routing decision.
- `argocd/platform/external-secrets/external-secrets.yaml` — wave-1 reference.
- `argocd/platform/istio/base.yaml` — wave −2 collision check.
- `kubernetes/manifests/secrets/grafana-admin-externalsecret.yaml` — ESO v1beta1 baseline.
- `kubernetes/helm/ml-batch-job/templates/_helpers.tpl` — SA name resolution.
- `kubernetes/helm/ml-batch-job/templates/service-account.yaml` — IRSA chain.
- `kubernetes/helm/ml-batch-job/templates/job-cpu.yaml` — SA + imagePullSecret consumers.
- `kubernetes/helm/ml-batch-job/templates/job-gpu.yaml` — SA + imagePullSecret consumers.
- `kubernetes/helm/values/quanvnn-dev.yaml` — full file context for opt-in.
- `platform-bot/internal/gitops/placeholders.go` — confirmed missing mapping for F3.

---

## Final verdict

**REQUEST_CHANGES** — F1 and F2 must be addressed before merge. Everything else
is either correct (C1, C5) or non-blocking polish.

If F1+F2 are added to this same PR (single 3-line patch on
`argocd/projects/platform.yaml`), the PR can flip to **APPROVE** without a
second review pass.
