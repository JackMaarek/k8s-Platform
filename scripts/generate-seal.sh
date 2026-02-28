#!/bin/bash
set -euo pipefail

# Generic secret sealing tool
# Usage: ./scripts/generate-seal.sh --name <name> --namespace <ns> [--type generic|docker-registry] [--from-literal key=value]... [--from-file key=path]...
# Examples:
#   ./scripts/generate-seal.sh --name lpcdm-supabase-secret --namespace development \
#     --from-literal VITE_SUPABASE_URL=https://xxx.supabase.co \
#     --from-literal VITE_SUPABASE_PUBLISHABLE_KEY=xxx
#
#   ./scripts/generate-seal.sh --name ghcr-pull-secret --namespace development --type docker-registry \
#     --docker-server ghcr.io \
#     --docker-username myuser \
#     --docker-password mytoken

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

check_kubeseal() {
  if ! command -v kubeseal &>/dev/null; then
    log_error "kubeseal not found — install it first:"
    echo "  macOS:  brew install kubeseal"
    echo "  Linux:  https://github.com/bitnami-labs/sealed-secrets/releases"
    exit 1
  fi
}

usage() {
  echo ""
  echo "Usage: $0 --name <name> --namespace <ns> [--type generic|docker-registry] [--from-literal key=value]... [--from-file key=path]..."
  echo ""
  echo "Examples:"
  echo "  # Generic secret"
  echo "  $0 --name lpcdm-supabase-secret --namespace development \\"
  echo "    --from-literal VITE_SUPABASE_URL=https://xxx.supabase.co \\"
  echo "    --from-literal VITE_SUPABASE_PUBLISHABLE_KEY=xxx"
  echo ""
  echo "  # Docker registry secret"
  echo "  $0 --name ghcr-pull-secret --namespace development --type docker-registry \\"
  echo "    --docker-server ghcr.io \\"
  echo "    --docker-username myuser \\"
  echo "    --docker-password mytoken"
  echo ""
  exit 1
}

main() {
  check_kubeseal

  local name=""
  local namespace=""
  local type="generic"
  local kubectl_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)        name="$2";      shift 2 ;;
      --namespace)   namespace="$2"; shift 2 ;;
      --type)        type="$2";      shift 2 ;;
      --from-literal|--from-file|--docker-server|--docker-username|--docker-password)
                     kubectl_args+=("$1" "$2"); shift 2 ;;
      --help|-h)     usage ;;
      *)             log_error "Unknown argument: $1"; usage ;;
    esac
  done

  [[ -z "$name" ]]      && log_error "--name is required"      && usage
  [[ -z "$namespace" ]] && log_error "--namespace is required" && usage

  local output="$ROOT_DIR/kubernetes/secrets/$namespace/$name.yaml"
  mkdir -p "$(dirname "$output")"

  log_info "Sealing secret $name in namespace $namespace..."

  kubectl create secret "$type" "$name" \
    --namespace "$namespace" \
    "${kubectl_args[@]}" \
    --dry-run=client -o yaml \
  | kubeseal \
      --controller-name sealed-secrets \
      --controller-namespace kube-system \
      --format yaml \
  > "$output"

  log_success "Sealed secret written to $output"
  log_warn "This file is safe to commit — encrypted with the cluster public key"

  kubectl apply -f "$output"
  log_success "$name applied to cluster (namespace: $namespace)"

  echo ""
  echo "  Commit:"
  echo "  git add $output"
  echo "  git commit -m 'chore: seal $name'"
  echo ""
}

main "$@"
