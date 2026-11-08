#!/usr/bin/env bash
# Test the built image with the same restrictions used in production.
set -euo pipefail

image="${1:-linux-workstation:local}"
token="test-token-0123456789abcdef"
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; exit 1; }
harden=(--read-only --tmpfs /tmp:exec --tmpfs /home/dev/.cache:uid=1000,gid=1000 --cap-drop ALL --security-opt no-new-privileges)

set +e
docker run --rm "$image" >/dev/null 2>&1
code=$?
set -e
[[ "$code" == 64 ]] && pass "refuses to start without a token" || fail "refuses to start without a token"

set +e
docker run --rm -e JUPYTER_TOKEN=short "$image" >/dev/null 2>&1
code=$?
set -e
[[ "$code" == 64 ]] && pass "refuses a short token" || fail "refuses a short token"

docker run --rm "${harden[@]}" "$image" workstation-verify | grep -q "ALL PASSED" \
  && pass "tools work with a read-only filesystem and no capabilities" \
  || fail "tools work with a read-only filesystem and no capabilities"

[[ "$(docker run --rm "$image" id -u)" == 1000 ]] && pass "runs as a non-root user" || fail "runs as a non-root user"

name="workstation-test-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" "${harden[@]}" -e JUPYTER_TOKEN="$token" "$image" >/dev/null
status=starting
for _ in $(seq 1 60); do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$name")"
  [[ "$status" == starting ]] || break
  sleep 2
done
[[ "$status" == healthy ]] && pass "health check reports healthy" || fail "health check reports healthy"

JUPYTER_TOKEN="$token" docker compose config -q && pass "compose file is valid" || fail "compose file is valid"
if env -u JUPYTER_TOKEN docker compose config -q 2>/dev/null; then fail "compose requires a token"; fi
pass "compose requires a token"
echo "ALL PASSED"
