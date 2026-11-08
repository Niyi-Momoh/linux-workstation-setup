#!/usr/bin/env bash
# Test a deployed workstation on any Kubernetes cluster.
set -euo pipefail

ns=workstation
k() { kubectl -n "$ns" "$@"; }
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; exit 1; }

pod() { k get pod -l app.kubernetes.io/name=workstation -o jsonpath='{.items[0].metadata.name}'; }

k rollout status deployment/workstation --timeout=300s >/dev/null
k wait --for=condition=complete job/verify-workstation --timeout=300s >/dev/null
k logs job/verify-workstation | grep -q "ALL PASSED" && pass "tools work inside the cluster" || fail "tools work inside the cluster"

[[ "$(k exec "$(pod)" -- id -u)" == 1000 ]] && pass "runs as a non-root user" || fail "runs as a non-root user"
if k exec "$(pod)" -- touch /should-not-work 2>/dev/null; then fail "root filesystem is read-only"; fi
pass "root filesystem is read-only"

k port-forward service/workstation 18888:8888 >/dev/null 2>&1 &
forward=$!
trap 'kill "$forward" 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do curl -fsS http://127.0.0.1:18888/api >/dev/null 2>&1 && break; sleep 1; done
token="$(k get secret workstation-token -o jsonpath='{.data.token}' | base64 -d)"
[[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18888/api)" == 200 ]] && pass "service responds" || fail "service responds"
[[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18888/api/contents)" == 403 ]] && pass "requests without the token are refused" || fail "requests without the token are refused"
[[ "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: token $token" http://127.0.0.1:18888/api/contents)" == 200 ]] && pass "requests with the token succeed" || fail "requests with the token succeed"
kill "$forward" 2>/dev/null || true

k exec "$(pod)" -- sh -c 'echo saved > /home/dev/workspace/persistence-check'
old="$(pod)"
k delete pod "$old" --wait=true >/dev/null
k rollout status deployment/workstation --timeout=300s >/dev/null
k wait --for=condition=Ready pod -l app.kubernetes.io/name=workstation --timeout=300s >/dev/null
[[ "$(k exec "$(pod)" -- cat /home/dev/workspace/persistence-check)" == saved ]] && pass "workspace survives a pod replacement" || fail "workspace survives a pod replacement"
k exec "$(pod)" -- rm -f /home/dev/workspace/persistence-check

if kubectl -n "$ns" run privileged-check --image=linux-workstation:local --dry-run=server \
    --overrides='{"spec":{"containers":[{"name":"x","image":"linux-workstation:local","securityContext":{"privileged":true}}]}}' >/dev/null 2>&1; then
  fail "privileged pods are rejected"
fi
pass "privileged pods are rejected"
echo "ALL PASSED"
