#!/bin/bash
# lib/prereqs.sh — verify required tools are installed before bootstrap starts
# Fails fast with a clear error list rather than crashing mid-run.
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

check_prereqs() {
  log_info "Checking prerequisites..."
  local missing=0

  for cmd in minikube kubectl helm kubeseal; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Missing: $cmd"
      missing=1
    fi
  done

  if [[ $missing -ne 0 ]]; then
    log_error "Install missing tools and re-run."
    exit 1
  fi

  log_success "All prerequisites found"
}
