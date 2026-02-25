#!/bin/bash
set -euo pipefail

# Monitoring stack installation
# Installs kube-prometheus-stack (Prometheus + Grafana + AlertManager), Loki and Promtail
# Usage: ./scripts/install-monitoring.sh

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

wait_for_pods() {
  local label="$1"
  local namespace="$2"
  local timeout="${3:-600s}"
  log_info "Waiting for pods ($label) in $namespace..."
  kubectl wait --for=condition=ready pod \
    -l "$label" \
    -n "$namespace" \
    --timeout="$timeout"
  log_success "Pods ready — $label"
}

check_prereqs() {
  log_info "Checking prerequisites..."
  for cmd in kubectl helm; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "$cmd is not installed"
      exit 1
    fi
  done
  log_success "Prerequisites found"
}

add_helm_repos() {
  log_info "Adding Helm repositories..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo update
  log_success "Helm repositories updated"
}

install_prometheus_stack() {
  log_info "Installing kube-prometheus-stack..."
  helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values "$ROOT_DIR/kubernetes/helm/monitoring/prometheus-values.yaml" \
    --timeout 10m \
    --wait
  wait_for_pods "app.kubernetes.io/name=grafana" "monitoring"
  wait_for_pods "app.kubernetes.io/name=prometheus" "monitoring"
  log_success "kube-prometheus-stack installed"
}

install_loki() {
  log_info "Installing Loki..."
  helm upgrade --install loki grafana/loki \
    --namespace monitoring \
    --values "$ROOT_DIR/kubernetes/helm/monitoring/loki-values.yaml" \
    --timeout 10m \
    --wait
  wait_for_pods "app.kubernetes.io/name=loki" "monitoring"
  log_success "Loki installed"
}

install_promtail() {
  log_info "Installing Promtail..."
  helm upgrade --install promtail grafana/promtail \
    --namespace monitoring \
    --values "$ROOT_DIR/kubernetes/helm/monitoring/promtail-values.yaml" \
    --timeout 5m \
    --wait
  log_success "Promtail installed"
}

apply_grafana_config() {
  # Apply datasources and dashboards ConfigMaps
  log_info "Applying Grafana datasources..."
  kubectl apply -f "$ROOT_DIR/kubernetes/manifests/grafana/datasources.yaml"

  log_info "Applying Grafana dashboards..."
  kubectl apply -f "$ROOT_DIR/kubernetes/manifests/grafana/dashboards/"
  log_success "Grafana config applied"
}

apply_servicemonitors() {
  log_info "Applying ServiceMonitors..."
  kubectl apply -f "$ROOT_DIR/kubernetes/manifests/servicemonitors/" 2>/dev/null \
    || log_warn "No ServiceMonitors applied — apps may not be deployed yet"
}

print_access() {
  local grafana_password
  grafana_password=$(kubectl get secret prometheus-grafana \
    -n monitoring \
    -o jsonpath="{.data.admin-password}" | base64 -d)

  echo ""
  log_success "Monitoring stack ready"
  echo ""
  echo "  Grafana"
  echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
  echo "  http://localhost:3000 — admin / $grafana_password"
  echo ""
  echo "  Prometheus"
  echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
  echo "  http://localhost:9090"
  echo ""
  echo "  AlertManager"
  echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093"
  echo "  http://localhost:9093"
  echo ""
}

main() {
  check_prereqs
  add_helm_repos
  install_prometheus_stack
  install_loki
  install_promtail
  apply_grafana_config
  apply_servicemonitors
  print_access
}

main "$@"