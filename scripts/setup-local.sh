#!/bin/bash
set -e

echo "=========================================="
echo "Kubernetes Platform - Local Setup"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

command -v minikube >/dev/null 2>&1 || { echo -e "${RED}Error: minikube is not installed${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is not installed${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Error: helm is not installed${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Start Minikube
echo "Starting Minikube cluster..."
minikube start \
  --cpus=4 \
  --driver=docker \
  --kubernetes-version=v1.28.3 \
  --addons=metrics-server \
  --alsologtostderr -v=8

echo -e "${GREEN}✓ Minikube started${NC}"
echo ""

# Apply namespaces
echo "Creating namespaces..."
kubectl apply -f kubernetes/namespaces/base-namespaces.yaml
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Verify cluster
echo "Verifying cluster..."
kubectl cluster-info
kubectl get nodes
echo ""

# Install sample application
echo "Do you want to install the sample application? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Installing sample application..."
    helm install sample-app kubernetes/helm/sample-app -n development
    echo -e "${GREEN}✓ Sample application installed${NC}"
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sample-app -n development --timeout=120s
    echo -e "${GREEN}✓ Sample application is ready${NC}"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n development"
echo "  kubectl get svc -n development"
echo "  helm list -n development"
echo "  minikube dashboard"
echo ""
echo "To access the sample app:"
echo "  kubectl port-forward -n development svc/sample-app 8080:80"
echo "  Then visit http://localhost:8080"
echo ""
