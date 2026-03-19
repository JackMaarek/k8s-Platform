# argocd

GitOps delivery layer for k8s-platform. ArgoCD watches this repository and reconciles
the cluster state with what is declared in Git.

---

## Structure

```
argocd/
  projects/
    platform.yaml        ← AppProject: infra (Istio, monitoring, ESO, Kyverno, namespaces)
    applications.yaml    ← AppProject: product apps (development, staging, production)
    ml.yaml              ← AppProject: ML batch workloads (Jobs, PVCs, IRSA)
  platform/
    namespaces.yaml      ← wave -3 — all cluster namespaces
    external-secrets/    ← wave -2 — ESO operator + ClusterSecretStore
    istio/               ← waves -1 to 1 — CNI, istiod, gateway
    kyverno/             ← wave 2 — admission policies
    monitoring/          ← waves 4-8 — prometheus, loki, promtail, grafana, opencost
    argocd/              ← wave 6 — ArgoCD self-monitoring ServiceMonitors
    development/         ← wave 6 — development namespace ServiceMonitors
  applications/
    ml/
      quanvnn.yaml       ← QuanvNN ML batch pipeline (dev)
```

---

## AppProjects

Three AppProjects define RBAC boundaries and allowed resource types:

| Project | Scope | Destinations | Teams |
|---|---|---|---|
| `platform` | Cluster infra — Istio, monitoring, ESO, namespaces | All system namespaces | platform-team |
| `applications` | Product apps — Deployments, Services, HPA | development, staging, production | dev-team, platform-team |
| `ml` | ML batch workloads — Jobs, PVCs, IRSA | ml | ml-team, platform-team |

---

## Sync waves

Resources are applied in strict wave order. Each wave waits for the previous to be healthy.

| Wave | ApplicationSet | Reason |
|------|---------------|--------|
| -3 | namespaces | Must exist before any workload |
| -2 | external-secrets | ESO must be ready before secrets are synced |
| -1 | istio-base, istio-cni | CRDs and CNI before istiod |
| 0 | istiod | Control plane before gateway |
| 1 | istio-gateway | Gateway after istiod |
| 2 | kyverno | Admission policies before workloads |
| 3 | kyverno policies | Policies after Kyverno CRDs |
| 4 | prometheus | Metrics stack — CRDs required by ServiceMonitors |
| 5 | loki, promtail | Log stack after prometheus |
| 6 | servicemonitors | ServiceMonitor CRDs must exist (wave 4) |
| 7 | grafana datasources, opencost | After prometheus and Grafana |
| 8 | grafana dashboards | After datasources |

---

## Placeholder syntax

Two placeholder syntaxes coexist in this repository — do not conflate them:

| Syntax | Replaced by | When |
|---|---|---|
| `__SNAKE_CASE__` | platform-bot | At `init` time — once per environment branch |
| `{{.camelCase}}` | ArgoCD goTemplate | At runtime — by ApplicationSet generators |

---

## Adding a product application

```bash
# 1. Create values file
cp kubernetes/helm/values/quanvnn-dev.yaml kubernetes/helm/values/<app>-dev.yaml
# edit values

# 2. Create ArgoCD Application
cp docs/examples/argocd-application.yaml argocd/applications/<app>.yaml
# edit name, namespace, values path

# 3. Commit
git add kubernetes/helm/values/<app>-dev.yaml argocd/applications/<app>.yaml
git commit -m "feat(app): add <app> to dev environment"
git push
```

ArgoCD detects the new Application manifest and syncs automatically.

---

## Adding an ML batch pipeline

```bash
# 1. Create values file
cp kubernetes/helm/values/quanvnn-dev.yaml kubernetes/helm/values/<app>-dev.yaml
# edit image, config, resources, runId

# 2. Create ArgoCD Application
cp argocd/applications/ml/quanvnn.yaml argocd/applications/ml/<app>.yaml
# edit name, values path

# 3. Commit
git add kubernetes/helm/values/<app>-dev.yaml argocd/applications/ml/<app>.yaml
git commit -m "feat(ml): add <app> ML pipeline to dev environment"
git push
```

---

## Triggering a new ML run

Increment `job.runId` in the values file and commit. ArgoCD creates new Jobs under the new name.
Previous Completed jobs are retained — prune manually when no longer needed.

```bash
# Edit kubernetes/helm/values/quanvnn-dev.yaml
# job:
#   runId: "v2"   ← increment

git add kubernetes/helm/values/quanvnn-dev.yaml
git commit -m "chore(ml): trigger quanvnn run v2"
git push
```

---

## Observability

ArgoCD exposes Prometheus metrics scraped by the `argocd-servicemonitors` ApplicationSet (wave 6).
The ArgoCD dashboard is available in Grafana under the `Platform` folder.

```bash
# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# CLI login
argocd login localhost:8080 --username admin --insecure

# Watch sync status
argocd app list
argocd app get quanvnn-dev
```

---

## Troubleshooting

```bash
# Application out of sync
argocd app diff <app-name>
argocd app sync <app-name> --force

# View sync history
argocd app history <app-name>

# Check controller logs
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Force refresh (re-read Git)
argocd app get <app-name> --refresh
```
