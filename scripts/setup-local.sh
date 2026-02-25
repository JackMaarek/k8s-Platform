#!/bin/bash
set -euo pipefail

# Main entrypoint for local cluster bootstrap
# Orchestrates all installation steps in the correct order
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
  read -r response
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

check_prereqs() {
  log_info "Checking prerequisites..."
  local missing=0
  for cmd in minikube kubectl helm; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "$cmd is not installed"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || exit 1
  log_success "All prerequisites found"
}

start_minikube() {
  log_info "Starting Minikube..."
  minikube start \
    --cpus=4 \
    --memory=8192 \
    --driver=docker \
    --kubernetes-version=v1.28.3 \
    --addons=metrics-server
  log_success "Minikube started"
  kubectl cluster-info
  kubectl get nodes
}

apply_namespaces() {
  log_info "Applying namespaces..."
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/base-namespaces.yaml"
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/monitoring-namespace.yaml"
  log_success "Namespaces created"
}

install_sample_app() {
  log_info "Installing sample application..."
  helm upgrade --install sample-app \
    "$ROOT_DIR/kubernetes/helm/sample-app" \
    --namespace development \
    --wait
  kubectl wait --for=condition=ready pod \
    -l "app.kubernetes.io/name=sample-app" \
    -n development \
    --timeout=120s
  log_success "Sample app installed"
}

print_summary() {
  echo ""
  log_success "Cluster ready"
  echo ""
  echo "  ArgoCD"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
  echo "  https://localhost:8001"
  echo ""
  echo "  Grafana"
  echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
  echo "  http://localhost:3000"
  echo ""
  echo "  Sample app"
  echo "  kubectl port-forward -n development svc/sample-app 8080:80"
  echo "  http://localhost:8080"
  echo ""
}

main() {
  echo ""
  echo -e "${BLUE}  PodYourLife — k8s-platform local setup${NC}"
  echo ""

  check_prereqs
  start_minikube
  apply_namespaces

  # Installation order matters:
  # 1. Sealed Secrets first — needed before any secret is applied
  # 2. ArgoCD — depends on Sealed Secrets for repo credentials
  # 3. Monitoring — independent, heavy, better installed before Istio
  # 4. Istio last — injects sidecars into all running pods

  if ask_yn "Install ArgoCD + Sealed Secrets?"; then
    bash "$SCRIPT_DIR/install-argocd.sh"
  fi

  if ask_yn "Install Prometheus + Grafana + Loki?"; then
    bash "$SCRIPT_DIR/install-monitoring.sh"
  fi

  if ask_yn "Install Istio?"; then
    bash "$SCRIPT_DIR/install-istio.sh"
  fi

  if ask_yn "Install sample application?"; then
    install_sample_app
  fi

  print_summary
}

main "$@"