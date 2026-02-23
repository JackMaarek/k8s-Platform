#!/bin/bash
set -e

echo "=========================================="
echo "Installing Monitoring Stack"
echo "Prometheus + Grafana + Loki"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is not installed${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Error: helm is not installed${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ Prerequisites installed${NC}"
echo ""

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl apply -f kubernetes/namespaces/monitoring-namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo -e "${GREEN}✓ Helm repositories added${NC}"
echo ""

# Install Prometheus Stack (includes Grafana)
echo "Installing Prometheus + Grafana Stack..."
echo -e "${YELLOW}This may take a few minutes...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values kubernetes/helm/monitoring/prometheus-values.yaml \
  --wait

echo -e "${GREEN}✓ Prometheus and Grafana installed${NC}"
echo ""

# Install Loki Stack
echo "Installing Loki Stack for logging..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values kubernetes/helm/monitoring/loki-values.yaml \
  --wait

echo -e "${GREEN}✓ Loki installed${NC}"
echo ""

# Wait for pods to be ready
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l "release=prometheus" -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l "app=loki" -n monitoring --timeout=300s

echo -e "${GREEN}✓ All monitoring pods are ready${NC}"
echo ""

# Apply ServiceMonitors
echo "Applying ServiceMonitor for sample app..."
kubectl apply -f kubernetes/manifests/sample-app-servicemonitor.yaml 2>/dev/null || echo -e "${YELLOW}Note: sample-app not deployed yet${NC}"

echo ""
echo "=========================================="
echo "Monitoring Stack Installation Complete!"
echo "=========================================="
echo ""

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d)

echo -e "${BLUE}=== Access Information ===${NC}"
echo ""
echo -e "${GREEN}Grafana:${NC}"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo ""
echo "  To access Grafana UI:"
echo -e "  ${YELLOW}kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80${NC}"
echo "  Then visit: http://localhost:3000"
echo ""
echo -e "${GREEN}Prometheus:${NC}"
echo "  To access Prometheus UI:"
echo -e "  ${YELLOW}kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090${NC}"
echo "  Then visit: http://localhost:9090"
echo ""
echo -e "${GREEN}AlertManager:${NC}"
echo "  To access AlertManager UI:"
echo -e "  ${YELLOW}kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093${NC}"
echo "  Then visit: http://localhost:9093"
echo ""
echo -e "${BLUE}=== Pre-installed Dashboards ===${NC}"
echo "  • Kubernetes Cluster (ID: 7249)"
echo "  • Kubernetes Pods (ID: 6417)"
echo "  • Istio Mesh (ID: 7639)"
echo "  • Istio Service (ID: 7636)"
echo "  • Istio Workload (ID: 7630)"
echo "  • Node Exporter (ID: 1860)"
echo ""
echo -e "${BLUE}=== Useful Commands ===${NC}"
echo "  View all monitoring pods:"
echo -e "    ${YELLOW}kubectl get pods -n monitoring${NC}"
echo ""
echo "  View Prometheus targets:"
echo -e "    ${YELLOW}kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090${NC}"
echo "    Then visit: http://localhost:9090/targets"
echo ""
echo "  View logs with Loki:"
echo "    Use Grafana's Explore feature with Loki datasource"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "  1. Access Grafana and explore pre-configured dashboards"
echo "  2. Configure AlertManager for notifications"
echo "  3. Create custom dashboards for your applications"
echo "  4. Set up alert rules for critical metrics"
echo ""
