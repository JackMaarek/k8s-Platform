#!/bin/bash
set -e

echo "=========================================="
echo "Kubernetes Platform - Cleanup"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}WARNING: This will delete the Minikube cluster and all resources!${NC}"
echo "Are you sure you want to continue? (yes/no)"
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS])$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Deleting Minikube cluster..."
minikube delete

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""
