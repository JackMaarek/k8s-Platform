# kubernetes

Helm charts, raw manifests, and namespace definitions for the k8s-platform.

---

## Structure

```
kubernetes/
  namespaces/              ← platform-managed namespace declarations
  helm/
    sample-app/            ← Helm chart for product apps (Deployment + Service + HPA)
    ml-batch-job/          ← Helm chart for ML batch pipelines (Job GPU + Job CPU)
    monitoring/            ← Helm values for the monitoring stack (prometheus, loki, grafana)
    values/                ← per-app value overrides (one file per app per env)
  manifests/
    monitoring/
      dashboards/          ← Grafana dashboard ConfigMaps (hot-loaded by k8s-sidecar)
      datasources/         ← Grafana datasource ConfigMaps
    argocd/
      servicemonitors/     ← ServiceMonitors for ArgoCD components
    development/
      servicemonitors/     ← ServiceMonitors for development namespace apps
  secrets/                 ← ExternalSecret CRDs (sync from AWS Secrets Manager via ESO)
```

---

## Namespaces

Namespaces are **platform infrastructure** — never created by application charts or manually.
All namespace declarations live in `kubernetes/namespaces/` and are managed by the
`namespaces` ApplicationSet (wave -3).

To add a new namespace:
1. Create `kubernetes/namespaces/<name>-namespace.yaml` following the existing pattern
2. Commit — the ApplicationSet picks it up automatically on the next sync

---

## Helm charts

### sample-app

Generic chart for **long-running product applications** (web services, APIs).

- `kind: Deployment` with HPA, PodDisruptionBudget, anti-affinity
- Configurable probes, resources, ingress, secret injection via ESO
- ServiceMonitor and Grafana dashboard enabled via values

Usage:
```bash
# Lint
helm lint kubernetes/helm/sample-app/

# Render with app-specific values
helm template my-app kubernetes/helm/sample-app/ \
  -f kubernetes/helm/values/my-app-dev.yaml
```

### ml-batch-job

Generic chart for **ML batch pipeline workloads** (training, feature extraction, analysis).

- `kind: Job` — run-to-completion, not long-running
- Optional GPU extraction job (step 1) + CPU training job (steps 2-N)
- Optional Prometheus metrics sidecar on the CPU job
- IRSA-based S3 access via dedicated ServiceAccount
- PersistentVolumeClaims for data, checkpoints, and results

Trigger model: **manual commit-based**. Increment `job.runId` in the values file to start a new run.
GPU nodes scale to zero between runs — zero compute cost at rest.

Usage:
```bash
# Lint with project values
helm lint kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml

# Render full pipeline
helm template quanvnn kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml
```

See `kubernetes/helm/ml-batch-job/values.yaml` for all available options.

---

## Values files

One file per application per environment: `kubernetes/helm/values/<app>-<env>.yaml`

```
values/
  quanvnn-dev.yaml         ← QuanvNN ML pipeline, dev environment
```

Only values that differ from the chart defaults need to be specified.
Chart defaults are documented in `kubernetes/helm/<chart>/values.yaml`.

---

## Raw manifests

Raw manifests in `kubernetes/manifests/` are **static platform components** — they do not
change per-project and require no templating. Examples: Grafana infrastructure dashboards,
platform-level ServiceMonitors (ArgoCD, Prometheus, Istio).

Application-level observability (ServiceMonitor, Grafana dashboard) belongs in the Helm chart
and is enabled via values — not in raw manifests.

---

## Secrets

ExternalSecret resources in `kubernetes/secrets/` declare which secrets to sync from
AWS Secrets Manager into native Kubernetes Secrets via ESO.

```bash
# Check sync status
kubectl get externalsecret -A

# Force refresh
kubectl annotate externalsecret <name> -n <ns> \
  force-sync=$(date +%s) --overwrite
```

See `docs/examples/external-secret.yaml` for the pattern.

---

## Common operations

```bash
# List all Helm releases across namespaces
helm list -A

# Check a specific release
helm status quanvnn -n ml

# View rendered templates without applying
helm template quanvnn kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml

# Dry-run apply
helm template quanvnn kubernetes/helm/ml-batch-job/ \
  -f kubernetes/helm/values/quanvnn-dev.yaml \
  | kubectl apply --dry-run=server -f -

# Check pod status across ML namespace
kubectl get pods -n ml
kubectl get jobs -n ml
kubectl get pvc -n ml
```
