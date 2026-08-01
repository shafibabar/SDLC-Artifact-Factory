#!/usr/bin/env bash
# tests/arch/lint-all.test.sh — smoke assertion for the governance gate runner
# scripts/lint-all.sh (P1.9, closes #790).
#
# Asserts the gate script:
#   * exists at scripts/lint-all.sh;
#   * is executable (the CI job and the arch smoke view both exec it directly);
#   * exits 0 on the current integration branch — i.e. every BLOCKING step
#     (schema + arch tests, lint-manifests) is green, and the report-only
#     steps (lint-duplication, lint-relationships) never gate;
#   * still emits the dynamic P2 backlog note for lint-relationships (proving
#     the reporting-only-for-now wiring is present, not silently dropped).
#
# Prints PASS:/FAIL: lines; exits 0 iff every assertion passed.
# Standalone-runnable:  bash tests/arch/lint-all.test.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$REPO_ROOT/scripts/lint-all.sh"

pass=0
fail=0
ok()   { echo "PASS: lint-all ($1)"; pass=$((pass + 1)); }
bad()  { echo "FAIL: lint-all ($1): $2"; fail=$((fail + 1)); }

# 1. exists
if [[ -f "$GATE" ]]; then
  ok "scripts/lint-all.sh exists"
else
  bad "scripts/lint-all.sh exists" "file not found at $GATE"
  echo "TOTAL: $pass passed, $fail failed"
  exit 1
fi

# 2. executable
if [[ -x "$GATE" ]]; then
  ok "scripts/lint-all.sh is executable"
else
  bad "scripts/lint-all.sh is executable" "missing +x bit"
fi

# 3. runs and exits 0 (blocking steps green on the integration branch)
GATE_OUT="$("$GATE" 2>&1)"
GATE_RC=$?
if [[ $GATE_RC -eq 0 ]]; then
  ok "gate exits 0 (all BLOCKING steps green)"
else
  bad "gate exits 0 (all BLOCKING steps green)" "exited $GATE_RC"
fi

# 4. the verdict line names a PASS
if grep -q "^PASS: all BLOCKING checks green" <<<"$GATE_OUT"; then
  ok "verdict reports BLOCKING checks green"
else
  bad "verdict reports BLOCKING checks green" "expected verdict PASS line absent"
fi

# 5. the P2 backlog note is present with a numeric broken-ref count
if grep -qE "lint-relationships: [0-9]+ broken 'related:' ref\(s\) — tracked P2 backlog" <<<"$GATE_OUT"; then
  ok "dynamic lint-relationships P2 backlog note present"
else
  bad "dynamic lint-relationships P2 backlog note present" "note missing or not dynamic"
fi

# 6. relationship step is reporting-only for now — its FAIL result must NOT
#    change the gate's exit code (already asserted by #3, but pin the intent)
if grep -q "REPORTING ONLY" <<<"$GATE_OUT"; then
  ok "lint-relationships labelled REPORTING ONLY"
else
  bad "lint-relationships labelled REPORTING ONLY" "label absent"
fi

echo "TOTAL: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
