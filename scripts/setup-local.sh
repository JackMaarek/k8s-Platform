#!/bin/bash
set -euo pipefail
# Bootstrap entrypoint for a local Minikube cluster.
#
# What this script does (and why each step is here, not in ArgoCD):
#   1. Minikube       — cluster must exist before kubectl works
#   2. Namespaces     — must exist before SealedSecrets can unseal into them
#   3. Sealed Secrets — controller must be Ready before any SealedSecret is applied
#   4. Secrets        — cluster-specific; re-sealed on each new cluster
#   5. ArgoCD         — must be installed before we can submit Applications
#   6. AppProjects    — must exist before Applications that reference them
#   7. Platform apps  — ArgoCD takes over from here (Istio, monitoring, ...)
#   8. App manifests  — product applications (empty on main, lpcdm on local-test)
#
# Do NOT add helm install calls here — use ArgoCD Applications in argocd/platform/.
#
# Usage: ./scripts/setup-local.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SCRIPT_DIR/lib"

source "$LIB/logging.sh"
source "$LIB/prereqs.sh"
source "$LIB/minikube.sh"
source "$LIB/namespaces.sh"
source "$LIB/secrets.sh"
source "$LIB/argocd.sh"
source "$LIB/summary.sh"

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
  wait_for_controller "sealed-secrets" "kube-system" "app.kubernetes.io/name=sealed-secrets"

  apply_secrets "development"

  if ask_yn "Install ArgoCD?"; then
    bash "$SCRIPT_DIR/install-argocd.sh" < /dev/tty
  fi

  # Repo credentials — ArgoCD needs this to pull from the private GitHub repo.
  # Must be applied after ArgoCD is installed and before platform apps sync.
  if [ -f "$ROOT_DIR/kubernetes/secrets/argocd/argocd-repo-creds.yaml" ]; then
    log_info "Applying ArgoCD repo credentials..."
    kubectl apply -f "$ROOT_DIR/kubernetes/secrets/argocd/argocd-repo-creds.yaml"
    log_success "Repo credentials applied"
  else
    log_warn "No argocd-repo-creds.yaml found — ArgoCD won't sync private repos"
    log_warn "Run: ./scripts/generate-seal.sh --name argocd-repo-creds --namespace argocd"
  fi

  apply_secrets "monitoring"

  apply_projects
  apply_platform
  apply_applications

  print_summary
}

main "$@"
