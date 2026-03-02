#!/bin/bash
set -euo pipefail
# Bootstrap entrypoint for a local Minikube cluster.
#
# What this script does (and why each step is here, not in ArgoCD):
#   1. Minikube    — cluster must exist before kubectl works
#   2. Namespaces  — must exist before secrets can be created
#   3. ArgoCD      — must be installed before we can submit Applications
#   4. AppProjects — must exist before Applications that reference them
#   5. Platform    — ArgoCD takes over (Istio, monitoring, ESO, ...)
#   6. Apps        — product Applications (empty on main)
#
# Secrets are managed by External Secrets Operator + AWS Secrets Manager.
# ESO is deployed as a platform Application (wave -1).
# See kubernetes/secrets/README.md for the secrets contract.
#
# Do NOT add helm install calls here — use ArgoCD Applications in argocd/platform/.
#
# Usage: ./scripts/setup-local.sh [--branch <branch>]
#   --branch  targetRevision for all ArgoCD platform Applications (default: HEAD)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SCRIPT_DIR/lib"

source "$LIB/logging.sh"
source "$LIB/prereqs.sh"
source "$LIB/minikube.sh"
source "$LIB/namespaces.sh"
source "$LIB/argocd.sh"
source "$LIB/summary.sh"

BRANCH="HEAD"
while [[ $# -gt 0 ]]; do
  case $1 in
    --branch) BRANCH="$2"; shift 2 ;;
    *) log_warn "Unknown argument: $1"; shift ;;
  esac
done

main() {
  echo ""
  echo -e "${BLUE}  k8s-platform local setup${NC}"
  echo ""

  check_prereqs
  start_minikube
  apply_namespaces

  if ask_yn "Install ArgoCD?"; then
    bash "$SCRIPT_DIR/install-argocd.sh" < /dev/tty
  fi

  # Hydrate targetRevision placeholder in all platform Applications
  log_info "Setting targetRevision to '$BRANCH'..."
  find "$ROOT_DIR/argocd/platform/" -name "*.yaml" \
    -exec sed -i '' "s/__TARGET_REVISION__/$BRANCH/g" {} +
  log_success "targetRevision set to '$BRANCH'"

  apply_projects
  apply_platform
  apply_applications

  print_summary
}

main "$@"
