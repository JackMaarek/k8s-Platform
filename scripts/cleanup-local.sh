#!/bin/bash
set -euo pipefail

# Deletes the local Minikube cluster and all resources
# Usage: ./scripts/cleanup-local.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

log_warn "This will delete the Minikube cluster and all resources!"
echo -e "${YELLOW}?${NC} Are you sure? [yes/no] "
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS])$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

minikube delete
log_success "Cluster deleted"