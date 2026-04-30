# PR #38 — Doc-Driven Review

**PR**: `feature/ml-batch-job-chart` → `main`
**Title**: `feat(ml): align QuanvNN dev pipeline with image contract and ml AppProject`
**Reviewer**: Independent doc-grounded pass via Context7 (ArgoCD `/websites/argo-cd_readthedocs_io_en_stable`, Kubernetes `/kubernetes/website`, Prometheus Operator)
**Date**: 2026-04-26
**Scope**: Two commits — `43fddde` (helm values) + `f3f69ff` (ArgoCD app)

---

## Verdict: **APPROVE** with one **non-blocking note** (Topic A, future-proofing)

The two in-scope commits make the right changes for the stated goal. Both align the chart-rendered pod spec with the image entrypoint contract, repoint the ArgoCD `Application` to the dedicated `ml` AppProject, and add an `ignoreDifferences` rule for the runtime `controller-uid` Pod label. All cross-checks against official documentation passed; the only forward-looking improvement is to also list the modern `batch.kubernetes.io/controller-uid` label key (added by the Kubernetes Job controller alongside the legacy one since 1.27 — KEP-2473), so this PR remains drift-free as the legacy label is eventually removed.

No security regression, no PSS violation, no AppProject scope leak, no chart contract mismatch, no identity-chain change.

---

## Procedural observations

### Diff scope clarification (not a defect)

`gh pr diff 38 --name-only` returns 39 files. This is the cumulative branch divergence vs `main`, **not** the delta of the two commits in scope. Both files modified by the two in-scope commits (`argocd/applications/ml/quanvnn.yaml` and `kubernetes/helm/values/quanvnn-dev.yaml`) were created earlier on this branch (commit `ee40c2d`), so they appear as "new files" in `git diff main..HEAD`. The actual delta of the two in-scope commits, obtained via `git diff 6a229d5..f3f69ff -- <files>`, is exactly the 5 documented changes (4 in `quanvnn-dev.yaml`, 2 in `quanvnn.yaml`). No collateral changes outside the announced scope.

### Branch hygiene

- `main` placeholders preserved: `__ENV__`, `__REPO_URL__`, `__TARGET_REVISION__`, `__IRSA_ROLE_ARN__` all intact in both files.
- No resolved values introduced. The branch remains a valid `platform-bot env hydrate` input.
- Helm chart was rendered locally with `helm template` against the modified values file: 9 manifests (1 SA, 2 ConfigMap, 3 PVC, 2 Job, 1 PodMonitor) — all syntactically valid, all in expected namespaces.

---

## Topic A — `ignoreDifferences` syntax + `controller-uid` label

### Doc reference
ArgoCD Operator Manual — *Diffing Customization* (https://argo-cd.readthedocs.io/en/stable/user-guide/diffing). `ignoreDifferences` accepts entries with `group`, `kind`, plus either `jsonPointers` (RFC 6901) or `jqPathExpressions`. JSON Pointer `~1` escape applies for `/` inside a key segment.

### What the PR adds

```yaml
ignoreDifferences:
  - group: batch
    kind: Job
    jsonPointers:
      - /status
  - group: ""               # core API group
    kind: Pod
    jsonPointers:
      - /metadata/labels/controller-uid
```

### Findings

1. **Syntax — PASS**. Both entries are valid ArgoCD `ignoreDifferences`. Empty string `""` for the core API group on Pod is the documented form. The path `/status` for batch/Job correctly suppresses ArgoCD's drift alarm on Job lifecycle status (which evolves at runtime as pods complete) — this is the standard pattern recommended for Job manifests in GitOps.

2. **Pod label key — PARTIAL coverage; non-blocking**. Per Kubernetes 1.27 enhancement KEP-2473, the Job controller now sets **two** labels on every child Pod for the same UID:
   - `controller-uid` (legacy — deprecated, still set as of K8s 1.33 for backward compat)
   - `batch.kubernetes.io/controller-uid` (new canonical key, set since 1.27)

   The same applies to `job-name` / `batch.kubernetes.io/job-name`. The current `ignoreDifferences` only ignores the legacy key. ArgoCD will still report drift on the new namespaced key as soon as it appears in the live state and not in the rendered manifest. With K8s 1.33 in this platform (`platform.yaml versions.kubernetes: "1.33"`), both keys are present at runtime — so the Application will likely show as `OutOfSync` on the new key.

   **Recommendation (Sprint 2)**: extend the rule to:

   ```yaml
   - group: ""
     kind: Pod
     jsonPointers:
       - /metadata/labels/controller-uid
       - /metadata/labels/batch.kubernetes.io~1controller-uid
       - /metadata/labels/job-name
       - /metadata/labels/batch.kubernetes.io~1job-name
   ```

   Note the `~1` JSON Pointer escape for `/` in `batch.kubernetes.io/controller-uid`. This is consistent with the ArgoCD docs' explicit example for keys containing slashes.

3. **Comment integrity — PASS**. The added one-line comment "Pod controller-uid label is set by kubelet at runtime — must be ignored." is accurate (technically it is set by the Job controller, not kubelet — minor wording nit, not a defect). It improves readability of the ignoreDifferences block.

---

## Topic B — Multi-source `$values` pattern stability (ArgoCD 7.8.26)

### Doc reference
ArgoCD User Guide — *Multiple Sources for an Application* (https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources). Multi-source Applications and the `$values` ref alias are stable; the documented declarative pattern matches the one used in this PR.

### What the file declares

```yaml
sources:
  - repoURL: __REPO_URL__
    targetRevision: __TARGET_REVISION__
    path: kubernetes/helm/ml-batch-job
    helm:
      releaseName: quanvnn
      valueFiles:
        - values.yaml
        - $values/kubernetes/helm/values/quanvnn-__ENV__.yaml
  - repoURL: __REPO_URL__
    targetRevision: __TARGET_REVISION__
    ref: values
```

### Findings

1. **Pattern conforms to docs — PASS**. The official example uses a chart source with `helm.valueFiles` referencing `$values/...` and a sibling source with `ref: values` (no `path`, no `chart`, no `helm`). This file matches that template exactly. The `releaseName: quanvnn` is preserved (Topic G).

2. **Single-repo multi-source — intentional and supported**. Both sources point at the same `__REPO_URL__` / `__TARGET_REVISION__`. The docs allow this; the `ref` source acts as a named handle so the chart source can use `$values/...` to reach files outside the chart directory. This is the standard pattern for a centralized `values/` directory shared by multiple Helm Applications, exactly the convention used elsewhere in this repo.

3. **No drift risk on resync**. Because both sources resolve to the same commit, there is no "split brain" between the chart and its overrides. Touching `quanvnn-dev.yaml` triggers a sync correctly.

4. **`valueFiles` ordering — PASS**. Chart `values.yaml` first, then `$values/.../quanvnn-__ENV__.yaml`. ArgoCD merges files in declared order, last-wins for scalars (Helm semantics). The override correctly lives in the second file.

---

## Topic C — AppProject scoping coverage

### Doc reference
ArgoCD Operator Manual — *Projects* (https://argo-cd.readthedocs.io/en/stable/operator-manual/projects). An Application is rejected by ArgoCD if a rendered resource's `group/kind` is not in the project's whitelist or if the destination namespace is not allowed. `clusterResourceWhitelist: []` denies all cluster-scoped objects.

### Rendered kinds vs project whitelist

| Rendered kind (group/kind) | In `ml.yaml` whitelist? |
|---|---|
| `core/ServiceAccount` | yes |
| `core/ConfigMap` (×2: `quanvnn-config` in `ml`, `quanvnn-dashboard` in `monitoring`) | yes |
| `core/PersistentVolumeClaim` (×3) | yes |
| `batch/Job` (×2) | yes |
| `monitoring.coreos.com/PodMonitor` | yes |
| `external-secrets.io/ExternalSecret` (chart-conditional, not currently rendered) | yes |

### Destinations

| Rendered namespace | In `ml.yaml destinations`? |
|---|---|
| `ml` (SA, ConfigMap, PVCs, Jobs, PodMonitor) | yes |
| `monitoring` (Grafana dashboard ConfigMap) | yes |

### Findings

1. **Scoping — PASS**. Every kind rendered today is covered. Both destination namespaces are explicit. `clusterResourceWhitelist: []` enforces zero cluster-scoped objects, consistent with the chart (which produces only namespaced resources).

2. **Project repoint correctness — PASS**. Changing `project: platform → ml` is the right call: the `ml` AppProject was added expressly to isolate ML workloads (GPU resources, IRSA, large PVCs, batch lifecycle) from the generic `platform` project. Before this commit the AppProject was effectively dead code. This commit activates it.

3. **Roles binding — informational**. `ml.yaml` already defines `ml-operator` (sync/override on `ml/*`) bound to the `ml-team` group, and `ml-readonly` bound to `dev-team`. Neither is exercised by this PR but both are now reachable as soon as the OIDC group claim is wired (deferred to a later sprint).

---

## Topic D — Helm values vs image contract alignment

### Doc reference
N/A (project code). Verified directly against `QuanvNN_MVP_infraReady/perspeqtive/fusion_qnn/scripts/run_all.py` (the entrypoint module name matches the Dockerfile `ENTRYPOINT`) and `perspeqtive/output_config.py` (`FUSION_DIR = OUTPUT_ROOT / "fusion"` → `/app/output/fusion`).

### Findings

1. **All CLI flags resolve in `run_all.py` argparse — PASS**. Verified for both pods:
   - GPU pod args: `--skip-calibrate`, `--skip-train`, `--skip-evaluate`, `--dataset-dir`, `--quanv-checkpoint-dir`, `--output-dir` — all four `--skip-*` flags exist (lines 117–135), `--dataset-dir`, `--quanv-checkpoint-dir`, `--output-dir` exist (lines 38–57).
   - CPU pod args: `--skip-extract` + the same four data flags — `--skip-extract` exists (line 117).
   - No stale or misspelled flags.

2. **Mount paths match flag values — PASS**. The PVC `mountPath` table lines up exactly with the args:
   | PVC | mountPath | Used by flag |
   |---|---|---|
   | data | `/data/dubai_data` | `--dataset-dir /data/dubai_data/Dubai256` (subdir, see below) |
   | checkpoints | `/data/quanv_ckpt` | `--quanv-checkpoint-dir /data/quanv_ckpt` |
   | results | `/app/output/fusion` | `--output-dir /app/output/fusion` |

   The results mountPath aligns with `FUSION_DIR` in `output_config.py`, the canonical output location. The previous value `/app/fusion_qnn/results` was a phantom path (no source-of-truth reference); replacing it was correct.

3. **`Dubai256` subdirectory — assumption, not yet verified at runtime**. The args pass `/data/dubai_data/Dubai256`, expecting that the PVC content (after S3 sync) is laid out as `<pvc-root>/Dubai256/...`. The Dockerfile CMD also defaults to this path, which is the strongest available signal that the maintainer's local layout matches. **Verification deferred to Sprint 3** when the S3 bucket and `aws s3 sync` initContainer land — the sync command must place the dataset under a top-level `Dubai256/` directory inside the data PVC for this to work end-to-end. Flagging here so it is not forgotten when authoring the initContainer.

4. **`gpu.enabled: true` — PASS**. The GPU job is now actually rendered. Previously the chart silently produced only the CPU job. This is the change that unblocks the GPU step on the next sync.

5. **`config:` shrunk to one key — PASS**. `DATASET_DIR`, `QUANV_CHECKPOINT_DIR`, `OUTPUT_DIR` removed because they were redundant with the CLI args (the entrypoint reads from `argv`, not env). `QUANV_CONFIG: basic_silhouette` retained — matches the `--quanv-config` argparse default in `run_all.py` line 61. No env-var-only consumer of the removed keys exists in the entrypoint.

---

## Topic E — GPU node selection + tolerations

### Doc reference
Kubernetes — *Taints and Tolerations* (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) and *Schedule GPUs* (https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/). The NVIDIA device plugin convention uses the resource key `nvidia.com/gpu`; a taint of the same key is the recommended pattern to keep non-GPU workloads off GPU nodes.

### Rendered GPU job pod spec (relevant fields)

```yaml
nodeSelector:
  node-group: gpu
tolerations:
  - effect: NoSchedule
    key: nvidia.com/gpu
    operator: Equal
    value: "true"
resources:
  limits: { nvidia.com/gpu: "1", cpu: "4", memory: 16Gi }
  requests: { nvidia.com/gpu: "1", cpu: "2", memory: 8Gi }
```

### Terraform GPU node group (`terraform/domains/platform/dev/terraform.tfvars`, prior context)

```hcl
node_groups.gpu = {
  instance_types = ["g4dn.xlarge"]
  capacity_type  = "SPOT"
  desired_size   = 0
  max_size       = 3
  labels = { "node-group" = "gpu", "nvidia.com/gpu" = "true" }
  taints = [{ key = "nvidia.com/gpu", value = "true", effect = "NO_SCHEDULE" }]
}
```

### Findings

1. **Selector / taint / toleration triangle — PASS**. The pod's `nodeSelector: node-group: gpu` matches the node group's `node-group=gpu` label. The toleration matches the taint (`key=nvidia.com/gpu`, `value=true`, `effect=NoSchedule`) one-for-one. EKS' `NO_SCHEDULE` translates to Kubernetes' `NoSchedule` — case is correct in the rendered spec.

2. **Resource request — PASS**. `nvidia.com/gpu: "1"` in both `requests` and `limits` is the documented contract (the device plugin admission requires `requests == limits` for the GPU resource — already satisfied).

3. **Scale-to-zero path — PASS**. With `desired_size: 0`, the GPU node group is empty until the Job pod is created. Cluster Autoscaler sees a Pending pod with the `nvidia.com/gpu` request and provisions a g4dn.xlarge spot instance. After the job completes, the node scales back to zero (CA respects the taint and won't keep the node warm without GPU workloads). Cost story is intact.

4. **CPU job nodeSelector — PASS**. `nodeSelector: node-group: standard` matches the `standard` node group label set in tfvars. No toleration needed (no taint on the standard node group).

---

## Topic F — PodMonitor cross-namespace discovery

### Doc reference
Prometheus Operator — *PodMonitor* CRD (https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.PodMonitor). The kube-prometheus-stack Helm chart selects PodMonitors via `spec.podMonitorSelector` — by default `release: <release-name>`, i.e. `release: prometheus` for the standard install. Cross-namespace discovery requires the `Prometheus` CR's `podMonitorNamespaceSelector` to either be empty (all namespaces) or explicitly include the target namespace.

### What the chart renders

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: quanvnn
  namespace: ml
  labels:
    release: prometheus            # required for kube-prometheus-stack discovery
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: quanvnn
      app.kubernetes.io/instance: quanvnn
      ml-platform/job-type: cpu-train
  namespaceSelector:
    matchNames: [ml]
  podMetricsEndpoints:
    - port: metrics
      path: /metrics
      interval: 30s
```

### Findings

1. **Discovery label — PASS**. `release: prometheus` matches the kube-prometheus-stack default `podMonitorSelector`. Without it, Prometheus would silently skip the resource.

2. **Cross-namespace prerequisite — already met by prior commit**. `f56662e` (out of in-scope review) added Prometheus RBAC to scrape the `ml` namespace; this is necessary because by default Prometheus' ServiceAccount only has read access in its own namespace. The `podMonitorNamespaceSelector` on the Prometheus CR must also accept `ml`. Worth verifying the Prometheus CR currently allows discovery from `ml`; if not, this PodMonitor will be silently ignored.

3. **Selector intentionally narrow — PASS**. The `matchLabels` includes `ml-platform/job-type: cpu-train`, which means the GPU extract job pods are **not** scraped (they lack that label). This is consistent with the design: training is the long-running step where loss/accuracy/epoch metrics matter; extraction is short and emits no time-series. If GPU-side metrics become useful later, either add a sibling PodMonitor or relax the selector.

4. **Sidecar container exposes port `metrics:8000` — PASS**. The rendered CPU pod has a `metrics-exporter` sidecar with `containerPort: 8000` named `metrics`, matching `podMetricsEndpoints[0].port`. Path `/metrics` is standard.

---

## Topic G — Identity chain regression check

### Findings

The Helm release identity chain is:

| Field | Source | Rendered value | Expected? |
|---|---|---|---|
| `nameOverride` | `quanvnn-dev.yaml` | `"quanvnn"` | yes (unchanged) |
| `helm.releaseName` | `quanvnn.yaml` (ArgoCD source) | `quanvnn` | yes (unchanged) |
| ServiceAccount name | `_helpers.tpl` → `<fullname>-sa` | `quanvnn-sa` | yes |
| ConfigMap name | `<fullname>-config` | `quanvnn-config` | yes |
| Job names | `<fullname>-train-{runId}`, `<fullname>-extract-{runId}` | `quanvnn-train-v1`, `quanvnn-extract-v1` | yes |
| PVC names | `<fullname>-{pvcName}` | `quanvnn-data`, `quanvnn-checkpoints`, `quanvnn-results` | yes |
| PodMonitor name | `<fullname>` | `quanvnn` | yes |
| `serviceAccountName` (pod spec) | `<fullname>-sa` | `quanvnn-sa` | yes |

**PASS — no identity drift**. None of the Sprint 1 edits touched naming, `nameOverride`, or `releaseName`. The IRSA placeholder `__IRSA_ROLE_ARN__` on the ServiceAccount remains and is still resolved by `platform-bot env hydrate`.

---

## Topic H — PSS restricted profile compatibility

### Doc reference
Kubernetes — *Pod Security Standards* (https://kubernetes.io/docs/concepts/security/pod-security-standards/). The `restricted` profile requires (non-exhaustive): `runAsNonRoot=true`, `allowPrivilegeEscalation=false`, `capabilities.drop` includes `ALL` (no `add`), `seccompProfile.type` is `RuntimeDefault` or `Localhost`, no host namespaces, no privileged.

### Pod-level securityContext (both jobs)

```yaml
securityContext:
  fsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
```

### Container-level securityContext (main + sidecar containers)

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 1000
```

### Findings

1. **All restricted-profile fields satisfied — PASS**:
   - `runAsNonRoot: true` ✓ (both pod and container scope, redundant but correct)
   - `runAsUser: 1000` ✓ (non-zero)
   - `allowPrivilegeEscalation: false` ✓
   - `capabilities.drop: [ALL]` ✓ (no `add` list)
   - `seccompProfile.type: RuntimeDefault` ✓
   - No `hostNetwork`, `hostPID`, `hostIPC`, `privileged` → defaults (false) → ✓

2. **`readOnlyRootFilesystem: false` — informational, not a PSS violation**. The restricted profile does not require a read-only root filesystem. (CIS Kubernetes Benchmark recommends it; PSS does not enforce.) The training process needs to write transient state (PyTorch caches, log files), so leaving this `false` is reasonable. Could be tightened later by mounting an `emptyDir` over `/tmp` and switching to `true`, but that is a hardening item, not a blocker.

3. **GPU container compatibility — PASS**. The NVIDIA device plugin does not require `privileged: true` since K8s 1.10+. The current container security context is compatible with `nvidia.com/gpu` resource scheduling.

4. **`fsGroup: 1000` on PVCs — PASS**. Aligns with `runAsUser: 1000`, ensuring the non-root user can read/write to the mounted PVCs without an init-container chown step.

---

## Cross-cutting observations

1. **GPU job has no metrics sidecar**. Only the CPU train job carries the `metrics-exporter` sidecar. This is consistent with the PodMonitor selector (Topic F.3). Decision is internally coherent; document this as the chart contract.

2. **Job retention is generous**. `ttlSecondsAfterFinished: 604800` (7 days) keeps Completed Jobs around for log inspection — matches the comment in the values file ("Previous Completed jobs are retained for log inspection"). The `ignoreDifferences` on `/status` makes this safe under ArgoCD, since the controller will not try to re-sync a Completed Job.

3. **Istio compatibility note**. The job templates carry a comment about Istio 1.27+ native sidecars (initContainer with `restartPolicy: Always`) so the pod can transition to Completed cleanly. With the platform on Istio 1.27.1 (`platform.yaml`), this is correct. No action needed here, but worth confirming the `ml` namespace has `istio-injection: enabled` if mTLS is required for the metrics scrape from `monitoring`.

4. **Dataset distribution path is the next blocker**. The chart now points at `/data/dubai_data/Dubai256`. The PVC is empty until something populates it. Sprint 3's S3 + initContainer story needs to:
   - Provision an S3 bucket via Terraform (`domains/platform`).
   - Create an IRSA role granting `s3:GetObject` / `s3:ListBucket` on that bucket — already partially scaffolded by `__IRSA_ROLE_ARN__`.
   - Add an `initContainers: [aws-cli]` entry in both job templates that runs `aws s3 sync s3://<bucket>/dubai/Dubai256/ /data/dubai_data/Dubai256/`.
   - Document the expected S3 layout (top-level `Dubai256/`) so the `--dataset-dir` argument continues to resolve.

5. **`ignoreDifferences` future-proofing (Topic A.2)** — single non-blocking item. Add the `batch.kubernetes.io/...` keys to the Pod ignore list so the Application stays Synced after the legacy keys are removed in a future Kubernetes release.

---

## Suggested follow-ups (not part of this PR)

| ID | Item | When |
|---|---|---|
| F-1 | Extend Pod `ignoreDifferences` with `batch.kubernetes.io/controller-uid` and `batch.kubernetes.io/job-name` (jsonPointer-escaped) | Sprint 2 |
| F-2 | Verify Prometheus CR `podMonitorNamespaceSelector` accepts `ml` (otherwise PodMonitor is silently dropped) | Sprint 2 |
| F-3 | Author S3 bucket Terraform + initContainer for dataset hydration; confirm `Dubai256/` top-level layout | Sprint 3 |
| F-4 | Decide whether GPU extract job needs metrics; if yes, second PodMonitor or selector relaxation | Sprint 3+ |
| F-5 | Optional hardening: `readOnlyRootFilesystem: true` + emptyDir over `/tmp` and `~/.cache` | Backlog |

---

## References

- ArgoCD multi-source: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources
- ArgoCD diffing customization: https://argo-cd.readthedocs.io/en/stable/user-guide/diffing
- ArgoCD AppProjects: https://argo-cd.readthedocs.io/en/stable/operator-manual/projects
- Kubernetes Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards
- Kubernetes Job controller labels (KEP-2473): https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps/2473-job-pod-failure-policy (and Job docs noting the `batch.kubernetes.io/...` rename)
- Kubernetes GPU scheduling: https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus
- Prometheus Operator PodMonitor CRD: https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.PodMonitor

---

**End of review.**
