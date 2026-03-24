#!/bin/bash
# ============================================================================
# seed-vault.sh — Seed Vault dev mode with platform secrets
#
# Run after Vault pod is Running on Kind.
# Re-run after every Kind cluster recreation (dev mode = in-memory).
#
# Usage:
#   ./docs/seed-vault.sh
#
# Prerequisites:
#   - kubectl configured for the Kind cluster
#   - Vault pod running in namespace vault
# ============================================================================

set -euo pipefail

VAULT_NS="vault"
VAULT_POD="vault-0"

# ── Prompt helpers ──────────────────────────────────────────────────────────

prompt() {
  local varname="$1"
  local message="$2"
  local default="${3:-}"
  local value

  if [ -n "$default" ]; then
    read -rp "$message [$default]: " value
    value="${value:-$default}"
  else
    while [ -z "${value:-}" ]; do
      read -rp "$message: " value
    done
  fi

  eval "$varname='$value'"
}

prompt_secret() {
  local varname="$1"
  local message="$2"
  local value

  while [ -z "${value:-}" ]; do
    read -rsp "$message: " value
    echo ""
  done

  eval "$varname='$value'"
}

# ── Wait for Vault ──────────────────────────────────────────────────────────

echo "=== Waiting for Vault pod ==="
kubectl wait --for=condition=Ready pod/${VAULT_POD} -n ${VAULT_NS} --timeout=120s

echo "=== Enabling KV v2 secrets engine ==="
kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV v2 already enabled"

# ── Grafana admin credentials ───────────────────────────────────────────────

echo ""
echo "--- Grafana admin credentials ---"
prompt GRAFANA_USER "Grafana admin username" "admin"
prompt_secret GRAFANA_PASS "Grafana admin password"

kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv put secret/platform/grafana-admin \
  admin-user="${GRAFANA_USER}" \
  admin-password="${GRAFANA_PASS}"
echo "✅ Grafana credentials stored"

# ── GHCR pull token ─────────────────────────────────────────────────────────

echo ""
echo "--- GHCR image pull token ---"

GHCR_USER=""
GHCR_TOKEN=""

# Auto-detect GitHub credentials via gh CLI
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  GH_TOKEN=$(gh auth token)
  GH_USER=$(gh api user --jq .login)
  MASKED_TOKEN="${GH_TOKEN:0:4}$(printf '*%.0s' $(seq 1 $((${#GH_TOKEN} - 8))))${GH_TOKEN: -4}"
  echo "⚠ PAT GitHub détecté sur la machine — user: ${GH_USER}, token: ${MASKED_TOKEN}"
  read -rp "Utiliser ce token ? [Y/n]: " USE_GH
  if [[ ! "${USE_GH}" =~ ^[Nn]$ ]]; then
    GHCR_USER="${GH_USER}"
    GHCR_TOKEN="${GH_TOKEN}"
  fi
fi

# Fallback: manual prompt if no token detected or user declined
if [ -z "${GHCR_TOKEN}" ]; then
  echo "Generate a GitHub PAT with read:packages scope at:"
  echo "  https://github.com/settings/tokens"
  prompt GHCR_USER "GitHub username"
  prompt_secret GHCR_TOKEN "GitHub PAT (read:packages)"
fi

DOCKER_AUTH=$(echo -n "${GHCR_USER}:${GHCR_TOKEN}" | base64)
DOCKER_CONFIG="{\"auths\":{\"ghcr.io\":{\"auth\":\"${DOCKER_AUTH}\"}}}"

kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv put secret/platform/ghcr-pull-token \
  .dockerconfigjson="${DOCKER_CONFIG}"
echo "✅ GHCR pull token stored"

# ── Optional: application secrets ───────────────────────────────────────────

echo ""
read -rp "Seed application secrets (QuanvNN)? [y/N]: " SEED_APPS
if [[ "${SEED_APPS}" =~ ^[Yy]$ ]]; then
  echo ""
  echo "--- QuanvNN application secrets ---"
  echo "Leave empty to skip a value."

  prompt QUANVNN_S3_BUCKET "S3 bucket name" ""
  prompt QUANVNN_AWS_REGION "AWS region" "eu-west-3"

  if [ -n "${QUANVNN_S3_BUCKET}" ]; then
    kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv put secret/apps/quanvnn \
      s3-bucket="${QUANVNN_S3_BUCKET}" \
      aws-region="${QUANVNN_AWS_REGION}"
    echo "✅ QuanvNN secrets stored"
  else
    echo "⏭️  Skipped QuanvNN secrets"
  fi
fi

# ── Verify ──────────────────────────────────────────────────────────────────

echo ""
echo "=== Stored secrets ==="
kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv list secret/platform/ 2>/dev/null || echo "No platform secrets"
kubectl exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv list secret/apps/ 2>/dev/null || echo "No app secrets"

echo ""
echo "=== Done. Vault seeded. ==="
