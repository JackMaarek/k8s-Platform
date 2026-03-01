#!/bin/bash
# lib/secrets.sh — apply SealedSecrets for a given namespace
# Sealed secrets are cluster-specific: they must be re-sealed when the cluster
# is recreated (minikube delete / new EKS). See scripts/generate-seal.sh.
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# wait_for_controller <name> <namespace> <label-selector> [timeout]
# Blocks until the controller pod is Ready. Called after helm install to ensure
# the controller can unseal before we apply SealedSecret resources.
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

# apply_secrets <namespace>
# Applies all *.yaml files found in kubernetes/secrets/<namespace>/.
# Skips silently if the directory is empty or missing (e.g. fresh clone before
# running generate-seal.sh).
apply_secrets() {
  local namespace="$1"
  local secrets_dir="$ROOT_DIR/kubernetes/secrets/$namespace"

  if [ ! -d "$secrets_dir" ] || \
     [ -z "$(find "$secrets_dir" -name '*.yaml' 2>/dev/null)" ]; then
    log_warn "No sealed secrets found for namespace '$namespace' — skipping"
    log_warn "Run ./scripts/generate-seal.sh to create them"
    return 0
  fi

  log_info "Applying sealed secrets for namespace '$namespace'..."
  kubectl apply -f "$secrets_dir"
  log_success "Sealed secrets applied for '$namespace'"
}
