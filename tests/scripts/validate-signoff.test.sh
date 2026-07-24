#!/bin/bash
# Tests skills/acceptance-sign-off/scripts/validate-signoff.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/acceptance-sign-off/scripts/validate-signoff.sh"
SCAFFOLD="$REPO_ROOT/skills/acceptance-sign-off/scripts/scaffold-signoff.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has three unfilled fields (customer rep, Decision,
# Rollout Action) -- must fail exactly those three, not the structural ones.
FRESH="$("$SCAFFOLD" acme "2026-08 classification v2")"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-signoff: a fresh scaffold with unfilled fields fails"
else
  _fail "validate-signoff: a fresh scaffold with unfilled fields fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "3 check(s) failed"; then
  _pass "validate-signoff: reports exactly 3 failed checks on a fresh scaffold"
else
  _fail "validate-signoff: reports exactly 3 failed checks on a fresh scaffold" "expected '3 check(s) failed'"
fi

if echo "$OUTPUT" | grep -q "PASS: Shafi named as sign-off authority" && echo "$OUTPUT" | grep -q "PASS: Sign-Off Criteria Checklist section present"; then
  _pass "validate-signoff: does not false-fail the checks that are already correct on a fresh scaffold"
else
  _fail "validate-signoff: does not false-fail the checks that are already correct on a fresh scaffold" "expected Shafi/checklist checks to pass even on a fresh scaffold"
fi

# Filling in all three fields makes it pass entirely.
sed -i 's/\[Name, role, company\]/Maya Chen, Compliance Lead, Acme Corp/' "$FRESH"
sed -i 's/## Decision: \[FULL SIGN-OFF \/ CONDITIONAL SIGN-OFF \/ NO-GO\]/## Decision: FULL SIGN-OFF/' "$FRESH"
sed -i 's/\[canary-deployment widen\/hold\/revert instruction; feature-flag-design scope change\]/canary-deployment widens to 100% and terminates./' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-signoff: filling in all three fields passes all checks"
else
  _fail "validate-signoff: filling in all three fields passes all checks" "expected exit 0 once all fields are filled in"
fi

# A malformed Decision line (not one of the three valid outcomes) must fail
# that specific check, even though a decision line exists.
sed -i 's/## Decision: FULL SIGN-OFF/## Decision: MOSTLY GOOD TO GO/' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: Decision line names exactly one valid outcome"; then
  _pass "validate-signoff: catches a Decision line that isn't one of the three valid outcomes"
else
  _fail "validate-signoff: catches a Decision line that isn't one of the three valid outcomes" "expected a FAIL line for the Decision check"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-signoff: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-signoff: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
