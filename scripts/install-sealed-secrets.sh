#!/bin/bash
set -euo pipefail

# Sealed Secrets controller installation
# Provides encrypted secrets safe to store in git
# Usage: ./scripts/install-sealed-secrets.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; }

install_sealed_secrets() {
  if helm status sealed-secrets -n kube-system &>/dev/null; then
    log_warn "Sealed Secrets already installed — skipping"
    return 0
  fi

  log_info "Adding Sealed Secrets Helm repo..."
  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
  helm repo update

  log_info "Installing Sealed Secrets controller..."
  helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
    --namespace kube-system \
    --wait
  log_success "Sealed Secrets controller installed"
}

check_kubeseal() {
  if ! command -v kubeseal &>/dev/null; then
    log_warn "kubeseal CLI not found — install it to seal secrets:"
    echo "  macOS:  brew install kubeseal"
    echo "  Linux:  https://github.com/bitnami-labs/sealed-secrets/releases"
  else
    log_success "kubeseal CLI found: $(kubeseal --version 2>/dev/null || echo 'unknown')"
  fi
}

main() {
  install_sealed_secrets
  check_kubeseal
}

main "$@"
