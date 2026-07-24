#!/bin/bash
# Tests skills/acceptance-criteria/scripts/validate-criteria.sh — a skill-owned
# script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/acceptance-criteria/scripts/validate-criteria.sh"
SCAFFOLD="$REPO_ROOT/skills/acceptance-criteria/scripts/scaffold-criteria.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has an unfilled Derived From placeholder -- must fail
# exactly that one check, not the structural ones.
FRESH="$("$SCAFFOLD" acme 042 "Classify a newly connected file")"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-criteria: a fresh scaffold with an unfilled Derived From fails"
else
  _fail "validate-criteria: a fresh scaffold with an unfilled Derived From fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "FAIL: Derived From links a real example map" && echo "$OUTPUT" | grep -q "1 check(s) failed"; then
  _pass "validate-criteria: names exactly the Derived From check as the failure"
else
  _fail "validate-criteria: names exactly the Derived From check as the failure" "expected exactly 1 failed check naming Derived From"
fi

# Filling in the Derived From field (a real example-map reference) makes it pass.
sed -i 's/EM-\[ID\]/EM-017/' "$FRESH"
if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-criteria: filling in a real Derived From reference passes all checks"
else
  _fail "validate-criteria: filling in a real Derived From reference passes all checks" "expected exit 0 once Derived From is filled in"
fi

# Injecting a testability red-flag word must fail that specific check.
sed -i 's/Then \[outcome\]\./Then the system should work properly./' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: no testability red-flag words"; then
  _pass "validate-criteria: catches a testability red-flag word (should/properly)"
else
  _fail "validate-criteria: catches a testability red-flag word (should/properly)" "expected a FAIL line for the red-flag-words check"
fi

# A doc missing a whole Golden Triangle section entirely must fail that
# specific section's check, distinct from the other two.
cat > "$SCRATCH_DIR/missing-section.md" <<'EOF'
---
name: acceptance-criteria
story-id: US-999
---

# Acceptance Criteria: US-999 — Missing a section

## Derived From
Example map: EM-005 (3 rule cards, 5 example cards, 0 open question cards)

## Happy Path

### AC-001: Works
```gherkin
Given a precondition,
When an action,
Then an outcome.
```

## Boundary / Edge Cases

### AC-002: Limit
```gherkin
Given a boundary,
When an action at the limit,
Then the expected behaviour.
```
EOF

OUTPUT3="$("$VALIDATE" "$SCRATCH_DIR/missing-section.md" 2>&1)"
if echo "$OUTPUT3" | grep -q "FAIL: Golden Triangle: '## Error / Negative Scenarios' present" && echo "$OUTPUT3" | grep -q "PASS: Golden Triangle: '## Happy Path' present"; then
  _pass "validate-criteria: catches a missing Golden Triangle section without false-failing the others present"
else
  _fail "validate-criteria: catches a missing Golden Triangle section without false-failing the others present" "expected FAIL only for the missing Error/Negative section"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-criteria: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-criteria: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
