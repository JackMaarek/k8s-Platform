#!/bin/bash
set -euo pipefail

# ArgoCD + Sealed Secrets installation
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

ask_yn() {
  local question="$1"
  echo -e "${YELLOW}?${NC} $question [y/n] "
  read -r response
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

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

install_sealed_secrets() {
  log_info "Installing Sealed Secrets controller..."
  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
  helm repo update
  helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
    --namespace kube-system \
    --wait
  log_success "Sealed Secrets controller installed"

  # Check kubeseal CLI availability
  if ! command -v kubeseal &>/dev/null; then
    log_warn "kubeseal CLI not found — install it to seal secrets:"
    echo "  macOS:  brew install kubeseal"
    echo "  Linux:  https://github.com/bitnami-labs/sealed-secrets/releases"
  else
    log_success "kubeseal CLI found"
  fi
}

install_argocd() {
  log_info "Creating argocd namespace..."
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

  log_info "Installing ArgoCD..."
  kubectl apply --server-side --force-conflicts \
    -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  wait_for_pods "app.kubernetes.io/name=argocd-server" "argocd" "600s"
  log_success "ArgoCD installed"
}

seal_git_secret() {
  log_info "Configuring Git repository access..."

  echo -e "${YELLOW}?${NC} GitHub repo URL (ex: https://github.com/PodYourLife/k8s-platform): "
  read -r REPO_URL

  echo -e "${YELLOW}?${NC} GitHub username: "
  read -r GIT_USER

  # Token is never written to disk — piped directly into kubeseal
  echo -e "${YELLOW}?${NC} GitHub Personal Access Token (hidden): "
  read -rs GIT_TOKEN
  echo ""

  log_info "Sealing the secret with cluster public key..."

  kubectl create secret generic argocd-repo-creds \
    --namespace argocd \
    --from-literal=type=git \
    --from-literal=url="$REPO_URL" \
    --from-literal=username="$GIT_USER" \
    --from-literal=password="$GIT_TOKEN" \
    --dry-run=client -o yaml \
  | kubeseal \
      --controller-name sealed-secrets \
      --controller-namespace kube-system \
      --format yaml \
  > "$ROOT_DIR/argocd/sealed-repo-creds.yaml"

  log_success "Sealed secret written to argocd/sealed-repo-creds.yaml"
  log_warn "This file is safe to commit — encrypted with the cluster public key"

  kubectl apply -f "$ROOT_DIR/argocd/sealed-repo-creds.yaml"
  log_success "Sealed secret applied to cluster"

  # Label required for ArgoCD to recognize the secret as a repo credential
  kubectl label secret argocd-repo-creds \
    -n argocd \
    argocd.argoproj.io/secret-type=repository \
    --overwrite
  log_success "Secret labeled for ArgoCD"
}

print_access() {
  local password
  password=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

  echo ""
  log_success "ArgoCD ready"
  echo ""
  echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
  echo "  https://localhost:8001"
  echo "  Username: admin"
  echo "  Password: $password"
  echo ""
  echo "  argocd login localhost:8001 --username admin --password $password --insecure"
  echo ""
}

main() {
  install_sealed_secrets
  install_argocd

  if command -v kubeseal &>/dev/null; then
    if ask_yn "Configure Git repository access now?"; then
      seal_git_secret
    fi
  else
    log_warn "Skipping Git config — install kubeseal first then re-run:"
    echo "  bash scripts/install-argocd.sh"
  fi

  print_access
}

main "$@"