# Local development — Kind cluster

This guide covers running the full platform stack locally using Kind.
It is the reference document for `platform-bot local up / down`.

---

## Prerequisites

The following tools must be installed and reachable on your `$PATH`.
`platform-bot check` verifies all of them before doing anything.

| Tool | Minimum version | Install |
|------|----------------|---------|
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Kind | v0.20+ | `brew install kind` or https://kind.sigs.k8s.io/ |
| kubectl | 1.29+ | `brew install kubectl` |
| Helm | 3.14+ | `brew install helm` |
| git | any | system package manager |

Docker must be **running** before `platform-bot local up` is called.
Kind requires at least **8 GB of memory** assigned to the Docker engine.

---

## Cluster topology

`platform-bot local up` creates a cluster named `k8s-platform-local` with:

```
control-plane (ingress-ready=true label)
  ├── port 80  → host 80   (HTTP ingress)
  ├── port 443 → host 443  (HTTPS ingress)
  └── port 30080 → host 30080 (ArgoCD NodePort)

worker-0
worker-1
```

This replicates EKS multi-node topology locally so that pod anti-affinity rules
and topology-spread constraints are exercised before hitting the cloud.

The Kubernetes version is read from `platform.yaml → environments.dev.kubernetes_version`.
Kind image: `kindest/node:v<kubernetes_version>.0`.

---

## Quick start

```bash
# 1. Clone and initialise the platform repo
platform-bot init

# 2. Verify all prerequisites are met
platform-bot check

# 3. Spin up the cluster and install the platform stack
platform-bot local up --env dev

# 4. Tear down when done
platform-bot local down
```

### What `local up` does — step by step

| Step | What happens |
|------|-------------|
| 1 | Validates `platform.yaml` and reads `kubernetes_version` + `istio_version` for the target env |
| 2 | Creates the Kind cluster (skips if already running) |
| 3 | Switches `kubectl` context to `kind-k8s-platform-local` |
| 4 | Applies namespace manifests from `kubernetes/namespaces/` |
| 5 | Installs ArgoCD via Helm (`argo/argo-cd`, NodePort on 30080) |
| 6 | Waits for `argocd-server` deployment to become Ready |
| 7 | Applies a mock `ClusterSecretStore` (Kubernetes native provider, replaces AWS Secrets Manager) |
| 8 | Applies AppProjects and platform ApplicationSets in wave order |
| 9 | Prints the ArgoCD initial admin password |

---

## Accessing ArgoCD

After `local up` completes:

```bash
# Get the initial admin password (also printed at the end of local up)
kubectl get secret argocd-initial-admin-secret \
  --namespace argocd \
  --output jsonpath='{.data.password}' | base64 -d && echo

# Open the UI — no port-forward needed, NodePort is mapped to localhost
open http://localhost:30080
# Username: admin
# Password: (from command above)
```

ArgoCD CLI:

```bash
argocd login localhost:30080 --username admin --insecure \
  --password "$(kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath='{.data.password}' | base64 -d)"

argocd app list
```

---

## Differences from the EKS cluster

| Concern | Kind (local) | EKS (cloud) |
|---------|-------------|-------------|
| Secret backend | Kubernetes native provider (mock) | AWS Secrets Manager via ESO |
| Ingress | NodePort 30080 | AWS Load Balancer Controller |
| Istio | Installed via ArgoCD ApplicationSet | Same |
| mTLS | PERMISSIVE in monitoring ns | STRICT cluster-wide |
| Node count | 1 control-plane + 2 workers | Configurable via node groups |
| IRSA | Not applicable | OIDC-backed IAM roles |

The mock `ClusterSecretStore` installed during `local up` is named
`aws-secrets-manager` — the same name used by `ExternalSecret` resources
pointing to AWS in the cloud. This means `ExternalSecret` CRDs work
without modification on both clusters.

---

## Troubleshooting

### Cluster creation fails

```bash
# Check Docker is running and has enough resources
docker info | grep -E "Memory|CPUs"

# Delete any stale cluster and retry
kind delete cluster --name k8s-platform-local
platform-bot local up --env dev
```

### ArgoCD pods stuck in Pending

```bash
kubectl get pods --namespace argocd
kubectl describe pod <pod-name> --namespace argocd
# Most common cause: Docker engine memory limit too low (raise to 8 GB)
```

### kubectl context not switching

```bash
# Check available contexts
kubectl config get-contexts

# Switch manually if needed
kubectl config use-context kind-k8s-platform-local
```

### Port 80 or 443 already in use

```bash
# Identify the process using the port
sudo lsof -i :80

# Stop the conflicting service, then retry
platform-bot local up --env dev
```

### ApplicationSet sync errors after local up

ArgoCD reconciles asynchronously. CRD-dependent resources (ESO, Kyverno)
may fail on the first sync wave and self-heal once their CRDs are installed.
Wait 2–3 minutes and run:

```bash
argocd app list
# or
kubectl get applications --namespace argocd
```

---

## Dry-run mode

Preview what `local up` would do without touching the cluster:

```bash
platform-bot local up --env dev --dry-run
```

Prints the Kind config that would be applied (cluster name, node image, port mappings)
and exits without creating any resource.

---

## Teardown

```bash
platform-bot local down
```

This runs `kind delete cluster --name k8s-platform-local`. All cluster state is
discarded. The `k8s-platform` repo directory is left untouched.
