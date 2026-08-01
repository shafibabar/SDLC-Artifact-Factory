#!/usr/bin/env bash
# tests/arch/lint-all.test.sh — smoke assertion for the governance gate runner
# scripts/lint-all.sh (P1.9, closes #790).
#
# Asserts the gate script:
#   * exists at scripts/lint-all.sh;
#   * is executable (the CI job and the arch smoke view both exec it directly);
#   * exits 0 on the current integration branch — i.e. every BLOCKING step
#     (schema + arch tests, lint-manifests, lint-relationships, catalog
#     staleness) is green, and the report-only step (lint-duplication) never
#     gates;
#   * still emits the dynamic broken-ref count for lint-relationships, and
#     labels that step BLOCKING (it was REPORTING ONLY until P2 drove the count
#     to 0 — the label is pinned so a silent regression is caught);
#   * runs the P3 catalog-staleness step and reports the committed catalog
#     current, with the verdict enumerating every blocking check.
#
# NOTE ON WHERE THIS FILE RUNS: it is executed by tests/run-smoke-tests.sh's
# 'arch' category, NOT by scripts/lint-all.sh itself. The gate's step 1 globs
# tests/arch/*.test.py deliberately — globbing *.test.sh there would make the
# gate run this file, which runs the gate, recursing without end.
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

# 5. the dynamic broken-ref note is present with a numeric count. P2 drove the
#    count to 0 and flipped this step to BLOCKING, so the note's wording changed
#    from "tracked P2 backlog" to "enforced since P2 close-out" — the count
#    itself must still be reported dynamically, not hard-coded.
if grep -qE "lint-relationships: [0-9]+ broken 'related:' ref\(s\) — enforced since P2 close-out" <<<"$GATE_OUT"; then
  ok "dynamic lint-relationships broken-ref count present"
else
  bad "dynamic lint-relationships broken-ref count present" "note missing or not dynamic"
fi

# 6. the relationship step is BLOCKING since P2 close-out (it was REPORTING ONLY
#    while the backlog stood). Pin the label so a silent regression to
#    report-only is caught.
if grep -qE "STEP 4/5[[:space:]]+lint-relationships\.py[[:space:]]+\[BLOCKING\]" <<<"$GATE_OUT"; then
  ok "lint-relationships labelled BLOCKING"
else
  bad "lint-relationships labelled BLOCKING" "label absent or still REPORTING ONLY"
fi

# 7. the P3 catalog-staleness step runs, is labelled BLOCKING, and reports the
#    committed catalog as current on a green tree
if grep -qE "STEP 5/5[[:space:]]+build-catalog\.py --check[[:space:]]+\[BLOCKING\]" <<<"$GATE_OUT"; then
  ok "catalog staleness step present and labelled BLOCKING"
else
  bad "catalog staleness step present and labelled BLOCKING" "step 5 banner absent"
fi

if grep -q "catalog is current" <<<"$GATE_OUT"; then
  ok "committed catalog reported current"
else
  bad "committed catalog reported current" "catalog reported stale on a clean tree"
fi

# 8. the verdict names every blocking check, so a step added without being
#    surfaced in the summary is caught
if grep -qE "PASS: all BLOCKING checks green .*lint-relationships, catalog" <<<"$GATE_OUT"; then
  ok "verdict enumerates the blocking checks incl. catalog"
else
  bad "verdict enumerates the blocking checks incl. catalog" "verdict does not name the catalog step"
fi

echo "TOTAL: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
