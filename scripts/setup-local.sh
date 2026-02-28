#!/bin/bash
set -euo pipefail

# Local cluster bootstrap — GitOps entrypoint
#
# This script is a MINIMAL bootstrapper. It only installs what ArgoCD needs
# to exist before it can manage everything else:
#
#   1. Minikube
#   2. Namespaces (needed before secrets can be applied)
#   3. Sealed Secrets controller (needed to decrypt secrets in the cluster)
#   4. Bootstrap secrets (argocd-secret, grafana credentials, app secrets)
#   5. ArgoCD
#   6. ArgoCD repo credentials (needed to pull from private GitHub repo)
#   7. kubectl apply argocd/platform/ — ArgoCD takes over from here
#   8. kubectl apply argocd/applications/ — app deployments
#
# After step 7, ArgoCD manages: Istio, Prometheus, Grafana, Loki, Promtail,
# dashboards, ServiceMonitors, and all application deployments.
#
# Do NOT add manual helm install calls here — use ArgoCD Applications instead.
#
# Usage: ./scripts/setup-local.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; }

ask_yn() {
  local question="$1"
  echo -e "${YELLOW}?${NC} $question [y/n] "
  read -r response < /dev/tty
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

check_prereqs() {
  log_info "Checking prerequisites..."
  local missing=0
  # istioctl is required at bootstrap time to verify the Istio install via ArgoCD
  for cmd in minikube kubectl helm kubeseal; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "$cmd is not installed"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || exit 1
  log_success "All prerequisites found"
}

start_minikube() {
  if minikube status 2>/dev/null | grep -q "Running"; then
    log_warn "Minikube already running — skipping"
    return 0
  fi

  log_info "Starting Minikube..."
  minikube start \
    --cpus=4 \
    --memory=10240 \
    --driver=docker \
    --kubernetes-version=v1.32.0 \
    --addons=metrics-server

  log_success "Minikube started"
  kubectl cluster-info
  kubectl get nodes
}

apply_namespaces() {
  # Namespaces must exist before sealed secrets can be applied to them
  log_info "Applying namespaces..."
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/base-namespaces.yaml"
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/monitoring-namespace.yaml"
  log_success "Namespaces applied"
}

wait_for_controller() {
  local name="$1"
  local namespace="$2"
  local label="$3"
  local timeout="${4:-120s}"
  log_info "Waiting for $name to be ready..."
  kubectl wait --for=condition=ready pod \
    -l "$label" \
    -n "$namespace" \
    --timeout="$timeout"
  log_success "$name ready"
}

apply_secrets() {
  local namespace="$1"
  local secrets_dir="$ROOT_DIR/kubernetes/secrets/$namespace"

  if [ ! -d "$secrets_dir" ] || \
     [ -z "$(find "$secrets_dir" -name '*.yaml' 2>/dev/null)" ]; then
    log_warn "No sealed secrets found for namespace $namespace — skipping"
    log_warn "Run ./scripts/generate-seal.sh to create secrets"
    return 0
  fi

  log_info "Applying sealed secrets for namespace $namespace..."
  kubectl apply -f "$secrets_dir"
  log_success "Sealed secrets applied for namespace $namespace"
}

apply_platform() {
  # Hand off to ArgoCD — from this point ArgoCD manages all platform components
  # ArgoCD will sync: Istio, Prometheus, Grafana, Loki, Promtail, dashboards, ServiceMonitors
  log_info "Applying ArgoCD platform applications..."
  kubectl apply -f "$ROOT_DIR/argocd/platform/" --recursive
  log_success "Platform applications submitted to ArgoCD"
}

apply_applications() {
  if [ -z "$(find "$ROOT_DIR/argocd/applications" -name '*.yaml' 2>/dev/null)" ]; then
    log_warn "No ArgoCD applications found — skipping"
    return 0
  fi

  log_info "Applying ArgoCD applications..."
  kubectl apply -f "$ROOT_DIR/argocd/applications/"
  log_success "Applications submitted to ArgoCD"
}

print_summary() {
  local argocd_password
  argocd_password=$(grep ARGOCD_ADMIN_PASSWORD "$ROOT_DIR/.argocd-secrets" \
    2>/dev/null | cut -d= -f2 || echo "see .argocd-secrets")

  echo ""
  log_success "Bootstrap complete — ArgoCD is syncing the platform"
  echo ""
  echo "  ArgoCD UI"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
  echo "  https://localhost:8001 — admin / $argocd_password"
  echo ""
  echo "  Watch sync progress"
  echo "  kubectl get applications -n argocd -w"
  echo ""
  echo "  Grafana (available once ArgoCD syncs the monitoring stack)"
  echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
  echo "  http://localhost:3000"
  echo ""
}

main() {
  echo ""
  echo -e "${BLUE}  PodYourLife — k8s-platform local setup${NC}"
  echo ""

  check_prereqs
  start_minikube
  apply_namespaces

  if ask_yn "Install Sealed Secrets?"; then
    bash "$SCRIPT_DIR/install-sealed-secrets.sh" < /dev/tty
  fi

  # Sealed Secrets controller must be Ready before applying any SealedSecret resources
  wait_for_controller \
    "sealed-secrets" \
    "kube-system" \
    "app.kubernetes.io/name=sealed-secrets"

  # App secrets (ghcr pull secret, supabase credentials)
  apply_secrets "development"

  if ask_yn "Install ArgoCD?"; then
    # install-argocd.sh also seals and applies argocd-secret (admin password + server.secretkey)
    # and seals grafana-admin-credentials — both require the cluster Sealed Secrets key
    bash "$SCRIPT_DIR/install-argocd.sh" < /dev/tty
  fi

  # Repo credentials — ArgoCD needs this to pull Helm values and manifests from GitHub
  if [ -f "$ROOT_DIR/kubernetes/secrets/argocd/argocd-repo-creds.yaml" ]; then
    log_info "Applying ArgoCD repo credentials..."
    kubectl apply -f "$ROOT_DIR/kubernetes/secrets/argocd/argocd-repo-creds.yaml"
    log_success "Repo credentials applied"
  else
    log_warn "No argocd-repo-creds.yaml found"
    log_warn "ArgoCD won't sync private repos until credentials are added"
    log_warn "Run: ./scripts/generate-seal.sh --name argocd-repo-creds --namespace argocd ..."
  fi

  # Monitoring secrets must exist before ArgoCD syncs the monitoring stack
  # grafana-admin-credentials is sealed inside install-argocd.sh
  apply_secrets "monitoring"

  apply_platform
  apply_applications

  print_summary
}

main "$@"

argocd app diff istio-base
lpcdm — Degraded
Normal — ImagePullBackOff sur l'image inexistante.
istio-gateway — Unknown
bashargocd app get istio-gateway --show-operation
Commence par prometheus et grafana-dashboards — ce sont les deux qui bloquent le monitoring. Partage le output de :
bashargocd app get prometheus
argocd app get grafana-dashboards