#!/bin/bash
set -e

echo "=========================================="
echo "Installing Argo CD"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create namespace
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Install Argo CD
echo "Installing Argo CD..."
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${GREEN}✓ Argo CD installed${NC}"
echo ""

# Wait for pods to be ready
echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo -e "${GREEN}✓ Argo CD is ready${NC}"
echo ""

# Get admin password
echo "Retrieving admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "=========================================="
echo "Argo CD Installation Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}Admin Username:${NC} admin"
echo -e "${GREEN}Admin Password:${NC} $ARGOCD_PASSWORD"
echo ""
echo "To access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8001:443"
echo "  Then visit https://localhost:8001"
echo ""
echo "To use Argo CD CLI:"
echo "  argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure"
echo ""
echo "To deploy the sample application:"
echo "  kubectl apply -f argocd/applications/sample-app.yaml"
echo ""
