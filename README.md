# Production-Grade Kubernetes Platform

⚠️ WIP ⚠️

## Overview
Complete Kubernetes platform with local development and AWS production support.

## Architecture
- **Local**: Minikube with Istio
- **Cloud**: AWS EKS with VPC, autoscaling, and service mesh
- **Deployment**: GitOps via Argo CD
- **IaC**: Terraform modules

## Quick Start
1. Local development: See [kubernetes/README.md](kubernetes/README.md)
2. AWS infrastructure: See [terraform/README.md](terraform/README.md)
3. Istio setup: See [istio/README.md](istio/README.md)
4. GitOps: See [argocd/README.md](argocd/README.md)
5. Monitoring & Logging: See [kubernetes/helm/monitoring/README.md](kubernetes/helm/monitoring/README.md)

## Directory Structure
```
k8s-platform/
├── terraform/          # Infrastructure as Code
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configs
├── kubernetes/         # Kubernetes manifests and Helm charts
│   ├── helm/           # Application Helm charts
│   │   ├── sample-app/ # Sample application
│   │   └── monitoring/ # Prometheus, Grafana, Loki configs
│   ├── manifests/      # Raw Kubernetes YAML
│   └── namespaces/     # Namespace definitions
├── istio/              # Service mesh configuration
│   ├── base/           # Base Istio installation
│   ├── security/       # Security policies
│   └── traffic/        # Traffic management
├── argocd/             # GitOps configurations
│   ├── bootstrap/      # Initial Argo CD setup
│   └── applications/   # Application definitions
├── scripts/            # Automation utilities
└── docs/               # Additional documentation
```

## Prerequisites
- Docker Desktop
- kubectl (1.28+)
- Helm 3 (3.12+)
- Terraform (1.6+)
- AWS CLI (configured)
- Minikube
- Git

## Local Development Workflow
```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# 
# You can either Apply components yourself (ex: base namespaces etc..)
kubectl apply -f kubernetes/namespaces/

# Or use the /scripts to install and deploy all the cluster's components.
chmod+x /scripts/install-istio.sh # Same for every component you need, monitoring, argocd whatever if you even want to incorporate your scripts. Maybe this will become too messy
./scripts/install-istio.sh

# Install sample application
helm install sample-app kubernetes/helm/sample-app -n development
```

## AWS Production Workflow
```bash
# Initialize Terraform
cd terraform/environments/dev
terraform init

# Plan and apply infrastructure
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region eu-west-3 --name dev-k8s-cluster
```

## Key Features
- ✅ Modular Infrastructure as Code
- ✅ GitOps continuous delivery
- ✅ Service mesh with strict mTLS
- ✅ Zero-trust security policies
- ✅ Horizontal and cluster autoscaling
- ✅ Production-ready Helm charts
- ✅ Complete monitoring stack (Prometheus + Grafana + Loki)
- 👷🏽 Generation of Argo, kube & prometheus dashboard configs to improve the DevX, DeployX (cookiecutter ?)
- 👷🏽 CI/CD checks non regression

## Documentation
Each major directory contains its own README with detailed instructions, architecture decisions, and troubleshooting guides.

## Contributing
Follow the Single Responsibility Principle for all code and configurations. Each module, chart, and manifest should have one clear purpose.

## License
Internal use only.
