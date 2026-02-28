#!/bin/bash
set -euo pipefail

# ArgoCD installation and bootstrap secret sealing
#
# Responsibilities:
#   1. Install ArgoCD from official manifests
#   2. Seal and apply argocd-secret (admin password + server.secretkey)
#      — re-sealed on every bootstrap because Sealed Secrets keys are cluster-specific
#   3. Seal and apply grafana-admin-credentials
#      — done here because the Sealed Secrets controller is already guaranteed ready
#
# Passwords are read from local .argocd-secrets and .grafana-secrets files (git-ignored).
# These files are created automatically on first run with default passwords.
#
# Usage: ./scripts/install-argocd.sh

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
  local timeout="${3:-300s}"
  log_info "Waiting for pods ($label) in $namespace..."
  kubectl wait --for=condition=ready pod \
    -l "$label" \
    -n "$namespace" \
    --timeout="$timeout"
  log_success "Pods ready in $namespace"
}

install_argocd() {
  if kubectl get namespace argocd &>/dev/null && \
     kubectl get deployment argocd-server -n argocd &>/dev/null; then

    # Re-apply manifests if RBAC is incomplete (e.g. partial previous install)
    if ! kubectl get role argocd-server -n argocd &>/dev/null; then
      log_warn "ArgoCD RBAC incomplete — re-applying manifests..."
      kubectl apply --server-side --force-conflicts \
        -n argocd \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      kubectl rollout restart deployment/argocd-server -n argocd
      kubectl rollout status deployment/argocd-server -n argocd --timeout=120s
      return 0
    fi

    log_warn "ArgoCD already installed — skipping"
    return 0
  fi

  log_info "Creating argocd namespace..."
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

  log_info "Installing ArgoCD..."
  kubectl apply --server-side --force-conflicts \
    -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  wait_for_pods "app.kubernetes.io/name=argocd-server" "argocd" "600s"
  log_success "ArgoCD installed"
}

seal_argocd_secret() {
  # argocd-secret contains:
  #   admin.password     — bcrypt hash of the admin password
  #   admin.passwordMtime — timestamp of last password change
  #   server.secretkey   — random key used to sign ArgoCD sessions (must be stable per cluster)
  #
  # The SealedSecret is re-generated on every bootstrap because the Sealed Secrets
  # encryption key is cluster-specific and changes on minikube delete/start.
  # The plaintext password is stored in .argocd-secrets (git-ignored).

  local secrets_file="$ROOT_DIR/.argocd-secrets"

  if [ ! -f "$secrets_file" ]; then
    log_warn "No .argocd-secrets file found — creating with default password"
    cat > "$secrets_file" <<EOF
ARGOCD_ADMIN_PASSWORD=admin123
EOF
    log_warn "Edit $secrets_file to change your password, then re-run"
  fi

  # shellcheck source=/dev/null
  source "$secrets_file"

  log_info "Sealing ArgoCD secret with current cluster key..."

  local password_hash
  # Generate bcrypt hash — ArgoCD requires $2a$ prefix (not $2y$)
  password_hash=$(htpasswd -nbBC 10 "" "$ARGOCD_ADMIN_PASSWORD" \
    | tr -d ':\n' | sed 's/$2y/$2a/')

  local password_mtime
  password_mtime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local server_key
  # 32-byte random hex key — stable for the lifetime of the cluster
  server_key=$(openssl rand -hex 32)

  mkdir -p "$ROOT_DIR/kubernetes/secrets/argocd"

  kubectl create secret generic argocd-secret \
    -n argocd \
    --from-literal=admin.password="$password_hash" \
    --from-literal=admin.passwordMtime="$password_mtime" \
    --from-literal=server.secretkey="$server_key" \
    --dry-run=client -o yaml \
  | kubeseal \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
    --format yaml \
  > "$ROOT_DIR/kubernetes/secrets/argocd/argocd-secret.yaml"

  log_success "ArgoCD secret sealed"

  # Remove any existing secret/sealedsecret before applying the new one
  kubectl delete secret argocd-secret -n argocd --ignore-not-found
  kubectl delete sealedsecret argocd-secret -n argocd --ignore-not-found
  kubectl apply -f "$ROOT_DIR/kubernetes/secrets/argocd/argocd-secret.yaml"

  log_info "Waiting for argocd-secret to be unsealed..."
  local retries=0
  until kubectl get secret argocd-secret -n argocd \
    -o jsonpath='{.data.admin\.password}' 2>/dev/null | grep -q .; do
    retries=$((retries + 1))
    if [[ $retries -ge 30 ]]; then
      log_error "Timed out waiting for argocd-secret to be unsealed"
      return 1
    fi
    sleep 2
  done

  # Restart to pick up the new secret
  kubectl rollout restart deployment/argocd-server -n argocd
  kubectl rollout restart deployment/argocd-dex-server -n argocd
  kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

  # Remove the auto-generated initial secret — we manage the password ourselves
  kubectl delete secret argocd-initial-admin-secret -n argocd --ignore-not-found
  log_success "ArgoCD admin password configured"
}

seal_grafana_secret() {
  # Grafana admin credentials are stored as a SealedSecret so they can be committed safely.
  # The SealedSecret is re-generated here for the same reason as argocd-secret.
  # The plaintext password is stored in .grafana-secrets (git-ignored).
  # prometheus-values.yaml references this secret via:
  #   grafana.admin.existingSecret: grafana-admin-credentials

  local secrets_file="$ROOT_DIR/.grafana-secrets"

  if [ ! -f "$secrets_file" ]; then
    log_warn "No .grafana-secrets file found — creating with default password"
    cat > "$secrets_file" <<EOF
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
EOF
    log_warn "Edit $secrets_file to change your password, then re-run"
  fi

  # shellcheck source=/dev/null
  source "$secrets_file"

  log_info "Sealing Grafana secret with current cluster key..."

  mkdir -p "$ROOT_DIR/kubernetes/secrets/monitoring"

  kubectl create secret generic grafana-admin-credentials \
    -n monitoring \
    --from-literal=admin-user="$GRAFANA_ADMIN_USER" \
    --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
    --dry-run=client -o yaml \
  | kubeseal \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
    --format yaml \
  > "$ROOT_DIR/kubernetes/secrets/monitoring/grafana-admin-credentials.yaml"

  kubectl apply -f "$ROOT_DIR/kubernetes/secrets/monitoring/grafana-admin-credentials.yaml"
  log_success "Grafana secret sealed and applied"
}

patch_repo_server() {
  # The argocd-repo-server init container needs argocd-cmp-server symlinked
  # to support Config Management Plugins — this patches the deployment once
  log_info "Patching argocd-repo-server init container..."
  kubectl patch deployment argocd-repo-server -n argocd --type=strategic \
    -p='{"spec":{"template":{"spec":{"initContainers":[{"name":"copyutil","command":["/bin/sh","-c","ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-cmp-server || true"]}]}}}}'
  kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s
  log_success "argocd-repo-server patched"
}

print_access() {
  local argocd_password
  argocd_password=$(grep ARGOCD_ADMIN_PASSWORD "$ROOT_DIR/.argocd-secrets" \
    | cut -d= -f2 || echo "see .argocd-secrets")

  echo ""
  log_success "ArgoCD ready"
  echo ""
  echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
  echo "  https://localhost:8001 — admin / $argocd_password"
  echo ""
}

main() {
  install_argocd
  seal_argocd_secret
  seal_grafana_secret
  patch_repo_server
  print_access
}

main "$@"
