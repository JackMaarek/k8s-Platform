#!/bin/bash
# lib/summary.sh — print cluster access info after successful bootstrap
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

print_summary() {
  local argocd_password
  argocd_password=$(grep ARGOCD_ADMIN_PASSWORD "$ROOT_DIR/.argocd-secrets" \
    2>/dev/null | cut -d= -f2 || echo "see .argocd-secrets")

  echo ""
  log_success "Bootstrap complete — ArgoCD is syncing the platform"
  echo ""
  echo "  ArgoCD UI"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
  echo "  https://localhost:8001 — admin / $argocd_password"
  echo ""
  echo "  Watch sync progress"
  echo "  kubectl get applications -n argocd -w"
  echo ""
  echo "  Grafana (available once ArgoCD syncs the monitoring stack)"
  echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
  echo "  http://localhost:3000"
  echo ""
}
