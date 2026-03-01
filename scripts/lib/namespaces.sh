#!/bin/bash
# lib/namespaces.sh — apply cluster namespaces
# Must run before secrets: SealedSecrets controller needs the target namespace
# to exist before it can unseal into it.
# kubectl apply is idempotent — safe to re-run.
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

apply_namespaces() {
  log_info "Applying namespaces..."
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/base-namespaces.yaml"
  kubectl apply -f "$ROOT_DIR/kubernetes/namespaces/monitoring-namespace.yaml"
  log_success "Namespaces applied"
}
