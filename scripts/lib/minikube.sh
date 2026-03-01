#!/bin/bash
# lib/minikube.sh — start Minikube if not already running
# Idempotent: skips gracefully if the cluster is already up.
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

start_minikube() {
  if minikube status 2>/dev/null | grep -q "Running"; then
    log_warn "Minikube already running — skipping"
    return 0
  fi

  log_info "Starting Minikube..."
  minikube start \
    --cpus=4 \
    --memory=10240 \
    --driver=docker \
    --kubernetes-version=v1.32.0 \
    --addons=metrics-server

  log_success "Minikube started"
  kubectl cluster-info
  kubectl get nodes
}
