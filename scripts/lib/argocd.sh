#!/bin/bash
# lib/argocd.sh — submit ArgoCD resources to the cluster
#
# Order matters:
#   1. apply_projects  — AppProjects must exist before Applications reference them
#   2. apply_platform  — platform Applications (Istio, monitoring, namespaces)
#   3. apply_applications — product Applications (lpcdm, etc.)
#
# All three functions use kubectl apply which is idempotent.
# ArgoCD takes over after apply_platform: subsequent changes are GitOps-driven.
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# apply_projects
# Applies all AppProject manifests from argocd/projects/.
# Waits for each project to be indexed by the ArgoCD controller before returning.
# Without this wait, a fast machine can submit Applications before the controller
# has registered the new AppProject, causing "project not found" errors.
apply_projects() {
  local projects_dir="$ROOT_DIR/argocd/projects"

  if [ ! -d "$projects_dir" ] || \
     [ -z "$(find "$projects_dir" -name '*.yaml' 2>/dev/null)" ]; then
    log_warn "No AppProject manifests found in argocd/projects/ — skipping"
    return 0
  fi

  log_info "Applying ArgoCD AppProjects..."
  kubectl apply -f "$projects_dir"

  log_info "Waiting for AppProjects to be indexed..."
  for project_file in "$projects_dir"/*.yaml; do
    local project_name retries=0
    project_name=$(grep '^  name:' "$project_file" | head -1 | awk '{print $2}')
    until kubectl get appproject "$project_name" -n argocd &>/dev/null; do
      retries=$((retries + 1))
      if [[ $retries -ge 20 ]]; then
        log_error "Timed out waiting for AppProject '$project_name'"
        return 1
      fi
      sleep 2
    done
    log_success "AppProject '$project_name' ready"
  done
}

# apply_platform
# Submits all platform Applications (argocd/platform/**) to ArgoCD.
# From this point ArgoCD manages: Istio, monitoring, namespaces, ServiceMonitors.
# Uses --recursive to pick up subdirectory structure (istio/, monitoring/, etc.)
apply_platform() {
  log_info "Applying ArgoCD platform applications..."
  kubectl apply -f "$ROOT_DIR/argocd/platform/" --recursive
  log_success "Platform applications submitted to ArgoCD"
}

# apply_applications
# Submits product Applications (argocd/applications/) to ArgoCD.
# Skips if the directory is empty — valid on main where no apps are committed.
apply_applications() {
  local apps_dir="$ROOT_DIR/argocd/applications"

  if [ -z "$(find "$apps_dir" -name '*.yaml' 2>/dev/null)" ]; then
    log_warn "No application manifests found in argocd/applications/ — skipping"
    return 0
  fi

  log_info "Applying ArgoCD applications..."
  kubectl apply -f "$apps_dir"
  log_success "Applications submitted to ArgoCD"
}
