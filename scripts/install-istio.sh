#!/bin/bash
set -e

echo "=========================================="
echo "Installing Istio Service Mesh"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if istioctl is installed
if ! command -v istioctl &> /dev/null; then
    echo -e "${YELLOW}istioctl not found. Downloading Istio...${NC}"
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*/
    export PATH=$PWD/bin:$PATH
    echo ""
    echo -e "${GREEN}✓ Istio downloaded${NC}"
    echo -e "${YELLOW}Add to PATH: export PATH=\$PWD/bin:\$PATH${NC}"
    echo ""
fi

# Install Istio
echo "Installing Istio with default profile..."
istioctl install --set profile=default -y

echo -e "${GREEN}✓ Istio installed${NC}"
echo ""

# Verify installation
echo "Verifying installation..."
kubectl get pods -n istio-system
echo ""

# Label namespaces for sidecar injection
echo "Enabling automatic sidecar injection for namespaces..."
kubectl label namespace development istio-injection=enabled --overwrite
kubectl label namespace staging istio-injection=enabled --overwrite
kubectl label namespace production istio-injection=enabled --overwrite

echo -e "${GREEN}✓ Namespaces labeled for sidecar injection${NC}"
echo ""

# Apply security policies
echo "Do you want to apply strict mTLS and authorization policies? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Applying PeerAuthentication policies..."
    kubectl apply -f istio/security/peer-authentication-strict.yaml
    
    echo "Applying AuthorizationPolicy policies..."
    kubectl apply -f istio/security/authorization-policy.yaml

    echo -e "${GREEN}✓ Security policies applied${NC}"
fi

echo ""
echo "=========================================="
echo "Istio Installation Complete!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  istioctl version"
echo "  istioctl verify-install"
echo "  istioctl analyze -A"
echo "  istioctl dashboard kiali"
echo "  kubectl get pods -n istio-system"
echo ""
echo "To check mTLS status:"
echo "  istioctl authn tls-check"
echo ""
