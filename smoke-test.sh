#!/bin/bash
# ── platform-bot smoke test ───────────────────────────────────────────────────
# Run from the ROOT of k8s-platform (must be a git repo).
#
# Usage:
#   bash smoke-test.sh                         # uses 'platform-bot' from PATH
#   BOT=~/test/platform-bot-bin bash smoke-test.sh
#
# NOTE: does NOT use set -e — each step is independent, failures are collected.

export GIT_PAGER=cat
BOT="${BOT:-platform-bot}"
SEP="─────────────────────────────────────────────"
FAILURES=0

ok()   { echo "  ✓ $1"; }
fail() { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES+1)); }
run()  {
  "$@"
  local rc=$?
  [ $rc -ne 0 ] && fail "exit code $rc for: $*"
  return 0
}

# ── DRY-RUN PASS ─────────────────────────────────────────────────────────────

echo ""; echo "$SEP"; echo "1. sync --env dev (dry-run)"; echo "$SEP"
run $BOT sync --env dev --dry-run

echo ""; echo "$SEP"; echo "2. set-version 1.33 --env dev (dry-run)"; echo "$SEP"
run $BOT set-version 1.33 --env dev --dry-run

echo ""; echo "$SEP"; echo "3. set-istio-version 1.27.1 --env dev (dry-run)"; echo "$SEP"
run $BOT set-istio-version 1.27.1 --env dev --dry-run

echo ""; echo "$SEP"; echo "4. enable-env staging (dry-run)"; echo "$SEP"
run $BOT enable-env staging --dry-run

echo ""; echo "$SEP"; echo "5. disable-env staging (dry-run)"; echo "$SEP"
run $BOT disable-env staging --dry-run

echo ""; echo "$SEP"; echo "6. app add standard (dry-run)"; echo "$SEP"
run $BOT app add --name smoke-app --namespace development --type standard --dry-run

echo ""; echo "$SEP"; echo "7. app add gpu-workload (dry-run)"; echo "$SEP"
run $BOT app add --name smoke-gpu --namespace development --type gpu-workload --dry-run

echo ""; echo "$SEP"; echo "8. nodegroup add standard (dry-run)"; echo "$SEP"
run $BOT nodegroup add --env dev --name smoke-pool --type t3.medium --capacity spot --dry-run

echo ""; echo "$SEP"; echo "9. nodegroup add gpu (dry-run)"; echo "$SEP"
run $BOT nodegroup add --env dev --name smoke-gpu-pool --type g4dn.xlarge --capacity on-demand --gpu --dry-run

# nodegroup remove dry-run is tested in step 14, AFTER the real write in step 13.
# dry-run remove requires the entry to already exist in the tfvars file.

echo ""; echo "$SEP"; echo "10. check"; echo "$SEP"
$BOT check || true   # kubectl not connected is expected in dev — not a failure

# ── WRITE PASS ────────────────────────────────────────────────────────────────

echo ""; echo "$SEP"; echo "── WRITE PASS ───────────────────────────────"; echo "$SEP"

echo ""; echo "11. sync --env dev (write)"
run $BOT sync --env dev

echo ""; echo "12. app add smoke-app (write)"
run $BOT app add --name smoke-app --namespace development --type standard

echo ""; echo "13. nodegroup add smoke-pool (write)"
run $BOT nodegroup add --env dev --name smoke-pool --type t3.medium --capacity spot

echo ""; echo "14. nodegroup remove dry-run (smoke-pool now exists in tfvars)"
run $BOT nodegroup remove --env dev --name smoke-pool --dry-run

echo ""; echo "15. nodegroup remove smoke-pool (write, --yes skips prompt)"
run $BOT nodegroup remove --env dev --name smoke-pool --yes

# ── FILE AUDIT ────────────────────────────────────────────────────────────────

echo ""; echo "$SEP"; echo "── FILE AUDIT ───────────────────────────────"; echo "$SEP"

echo ""; echo "--- platform.yaml ---"
cat platform.yaml

echo ""; echo "--- argocd istio base (targetRevision) ---"
grep "targetRevision" argocd/platform/istio/base.yaml

echo ""; echo "--- namespaces.yaml (enabled fields) ---"
grep -E '"enabled":|enabled:' argocd/platform/namespaces.yaml | grep -v "#"

echo ""; echo "--- secret-store dev ---"
cat kubernetes/secrets/dev/secret-store.yaml 2>/dev/null || echo "MISSING"

echo ""; echo "--- smoke-app deployment ---"
cat kubernetes/manifests/development/smoke-app/deployment.yaml 2>/dev/null || echo "MISSING"

echo ""; echo "--- smoke-app service ---"
cat kubernetes/manifests/development/smoke-app/service.yaml 2>/dev/null || echo "MISSING"

echo ""; echo "--- smoke-app service-monitor ---"
cat kubernetes/manifests/development/smoke-app/service-monitor.yaml 2>/dev/null || echo "MISSING"

echo ""; echo "--- smoke-app argocd application ---"
cat argocd/applications/applications/smoke-app.yaml 2>/dev/null || echo "MISSING"

echo ""; echo "--- terraform/domains/platform/dev/terraform.tfvars ---"
cat terraform/domains/platform/dev/terraform.tfvars 2>/dev/null || echo "MISSING"

# ── ASSERTIONS ────────────────────────────────────────────────────────────────

echo ""; echo "$SEP"; echo "── ASSERTIONS ───────────────────────────────"; echo "$SEP"

chk() {
  grep -q "$2" "$1" 2>/dev/null \
    && ok "$1 ∋ '$2'" \
    || { fail "$1 missing '$2'"; }
}
chk_not() {
  grep -q "$2" "$1" 2>/dev/null \
    && fail "$1 still contains '$2'" \
    || ok "$1 ∌ '$2' (correct)"
}
chk_file() {
  [ -f "$1" ] && ok "$1 exists" || fail "$1 MISSING"
}

# sync targets
chk "argocd/platform/istio/base.yaml"    "targetRevision: 1.27.1"
chk "argocd/platform/istio/cni.yaml"     "targetRevision: 1.27.1"
chk "argocd/platform/istio/istiod.yaml"  "targetRevision: 1.27.1"
chk "argocd/platform/istio/gateway.yaml" "targetRevision: 1.27.1"
chk "kubernetes/secrets/dev/secret-store.yaml" "region: eu-west-3"

# app add files
for f in deployment service hpa service-monitor external-secret virtual-service destination-rule; do
  chk_file "kubernetes/manifests/development/smoke-app/${f}.yaml"
done
chk_file "argocd/applications/applications/smoke-app.yaml"

# service correctness
chk "kubernetes/manifests/development/smoke-app/service.yaml"         "name: http"
chk "kubernetes/manifests/development/smoke-app/service-monitor.yaml" "port: http"

# nodegroup remove — smoke-pool must be gone
chk_not "terraform/domains/platform/dev/terraform.tfvars" "smoke-pool"

echo ""; echo "$SEP"
if [ "$FAILURES" -eq 0 ]; then
  echo "  ✓ ALL ASSERTIONS PASSED"
else
  echo "  ✗ $FAILURES ASSERTION(S) FAILED"
fi
echo "$SEP"

echo ""; echo "── GIT STATUS ───────────────────────────────"
git status
git diff --stat

exit $FAILURES
