# ml-batch-job

Generic Helm chart for ML batch pipeline workloads on the PodYourLife platform.

---

## Overview

This chart is the single reusable template for all ML batch workloads.
It is not tied to any specific project — project-specific values live in
`kubernetes/helm/values/<app>-<env>.yaml`.

One new ML project = one values file + one ArgoCD Application. No chart modification required.

---

## What this chart deploys

| Resource | Condition | Purpose |
|---|---|---|
| `ServiceAccount` | always | Dedicated SA per project — optional IRSA annotation for S3 access |
| `ConfigMap` | always | Environment variables injected into all job containers |
| `PersistentVolumeClaim` | one per entry in `persistentVolumes` | Data, checkpoints, results — survive Job completion |
| `Job` (GPU) | `gpu.enabled: true` | Step 1 — quantum/GPU feature extraction |
| `Job` (CPU) | always | Steps 2-N — classical training or analysis |
| `ExternalSecret` | `imagePullSecret.enabled: true` | Syncs GHCR pull token from AWS Secrets Manager |
| `ServiceMonitor` | `metrics.serviceMonitor.enabled: true` | Prometheus scraping of the metrics sidecar |
| `ConfigMap` (dashboard) | `metrics.grafanaDashboard.enabled: true` | Grafana dashboard hot-loaded by k8s-sidecar |

---

## Trigger model

Jobs are triggered by **committing a new `job.runId`** in the values file. Kubernetes treats
a different Job name as a new resource — the previous Completed job is not deleted automatically.

```yaml
# kubernetes/helm/values/quanvnn-dev.yaml
job:
  runId: "v2"   # ← increment to trigger a new run
```

```bash
git add kubernetes/helm/values/quanvnn-dev.yaml
git commit -m "chore(ml): trigger quanvnn run v2"
git push
# ArgoCD detects the change → creates quanvnn-extract-v2 and quanvnn-train-v2
```

---

## Cost model

GPU nodes are defined with `desired_size: 0` in `terraform.tfvars`. The Cluster Autoscaler
provisions a GPU node when the GPU Job is created, and releases it after the Job completes.

**Cost at rest: zero compute.** Only PVC storage costs apply between runs (~$2-5/mo for 40Gi).

---

## Istio and Jobs

The `ml` namespace has `istio-injection: disabled` (no `istio-injection` label on the
Namespace). Pods are not injected with an Envoy sidecar — no per-pod opt-out annotation
is required.

Rationale: Envoy does not terminate when the main container exits, blocking batch Jobs
from reaching `Completed` status. The PSS `restricted` profile enforced on this namespace
also rejects the `istio-init` initContainer (`NET_ADMIN`, `runAsUser=0`). ML jobs have no
inbound mesh traffic and access AWS S3 via IRSA + AWS SDK (TLS native) — the sidecar
provides no security benefit here.

---

## Values reference

All values with their defaults and descriptions are documented in `values.yaml`.

Key sections:

| Section | Key values | Purpose |
|---|---|---|
| Run control | `job.runId` | Trigger a new run by incrementing |
| Images | `image.gpu.*`, `image.cpu.*` | Container images per job type |
| GPU job | `gpu.enabled`, `gpu.args`, `gpu.resources` | Optional step 1 |
| CPU job | `cpu.args`, `cpu.resources` | Always-on steps 2-N |
| Storage | `persistentVolumes[].name/storage/accessMode` | PVC definitions |
| Config | `config` | Env vars injected into all containers |
| Metrics | `metrics.enabled`, `metrics.serviceMonitor.enabled` | Observability opt-in |
| Security | `podSecurityContext`, `containerSecurityContext` | PSS restricted defaults |
| IRSA | `serviceAccount.irsaRoleArn` | AWS API access without static credentials |

---

## Adding a new ML project

```bash
# 1. Copy QuanvNN values as a starting point
cp kubernetes/helm/values/quanvnn-dev.yaml kubernetes/helm/values/<app>-dev.yaml

# 2. Edit the values file — at minimum update:
#    - nameOverride
#    - image.gpu.repository / image.cpu.repository + tags
#    - gpu.args / cpu.args (CLI flags for your entrypoint)
#    - config (environment variables)
#    - persistentVolumes (sizes)
#    - serviceAccount.irsaRoleArn (provisioned by Terraform)

# 3. Copy the ArgoCD Application
cp argocd/applications/ml/quanvnn.yaml argocd/applications/ml/<app>.yaml
# Update: metadata.name, spec.sources[0].helm.valueFiles

# 4. Lint and render
helm lint kubernetes/helm/ml-batch-job/ -f kubernetes/helm/values/<app>-dev.yaml
helm template <app> kubernetes/helm/ml-batch-job/ -f kubernetes/helm/values/<app>-dev.yaml

# 5. Commit
git add kubernetes/helm/values/<app>-dev.yaml argocd/applications/ml/<app>.yaml
git commit -m "feat(ml): add <app> ML pipeline"
```

---

## Validation

```bash
# Lint
helm lint kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml

# Full render — GPU disabled (default)
helm template quanvnn kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml

# Dry-run against cluster
helm template quanvnn kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml \
  | kubectl apply --dry-run=server -f -
```
