#!/bin/bash
set -euo pipefail

# Istio service mesh installation
# Applies security policies and labels namespaces for sidecar injection
# Usage: ./scripts/install-istio.sh

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

install_istioctl() {
  if ! command -v istioctl &>/dev/null; then
    log_warn "istioctl not found — downloading..."
    curl -L https://istio.io/downloadIstio | sh -
    # Add to PATH for current session
    export PATH="$PWD/$(ls -d istio-*/)/bin:$PATH"
    log_success "istioctl downloaded"
    log_warn "Add to PATH permanently: export PATH=\$PWD/istio-<version>/bin:\$PATH"
  else
    log_success "istioctl found: $(istioctl version --short 2>/dev/null || echo 'unknown')"
  fi
}

install_istio() {
  log_info "Installing Istio with default profile..."
  istioctl install --set profile=default -y
  log_success "Istio installed"

  log_info "Verifying installation..."
  kubectl get pods -n istio-system
}

label_namespaces() {
  # Enable automatic sidecar injection on app namespaces
  log_info "Labeling namespaces for sidecar injection..."
  for ns in development staging production; do
    kubectl label namespace "$ns" istio-injection=enabled --overwrite
    log_success "Namespace $ns labeled"
  done
}

apply_security_policies() {
  log_info "Applying strict mTLS policy..."
  kubectl apply -f "$ROOT_DIR/istio/security/peer-authentication-strict.yaml"
  log_success "mTLS policy applied"

  log_info "Applying Istio traffic config (VirtualServices, DestinationRules, AuthorizationPolicies)..."
  helm upgrade --install istio-config "$ROOT_DIR/istio/helm" \
    --namespace istio-system \
    --wait
  log_success "Istio traffic config applied"
}

print_access() {
  echo ""
  log_success "Istio ready"
  echo ""
  echo "  istioctl version"
  echo "  istioctl verify-install"
  echo "  istioctl analyze -A"
  echo "  kubectl get pods -n istio-system"
  echo ""
  echo "  # Check mTLS status"
  echo "  istioctl authn tls-check"
  echo ""
}

main() {
  install_istioctl
  install_istio
  label_namespaces

  if ask_yn "Apply security policies and traffic config?"; then
    apply_security_policies
  fi

  print_access
}

main "$@"