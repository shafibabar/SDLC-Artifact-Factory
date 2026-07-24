#!/bin/bash
# Tests skills/aggregate-design/scripts/scaffold-aggregate-design.sh — a
# skill-owned script exercised directly with CLI args.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/aggregate-design/scripts/scaffold-aggregate-design.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme Classification)"
if [ "$OUT" = "artifacts/acme/design/classification/aggregate-design.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-aggregate-design: writes to the expected path"
else
  _fail "scaffold-aggregate-design: writes to the expected path" "got: $OUT"
fi

if grep -q "^product: acme$" "$OUT" && grep -q "^bounded-context: Classification$" "$OUT" && grep -q "^# Aggregate Design: Classification$" "$OUT"; then
  _pass "scaffold-aggregate-design: product/context filled in correctly, both placeholder occurrences resolved"
else
  _fail "scaffold-aggregate-design: product/context filled in correctly, both placeholder occurrences resolved" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-aggregate-design: date filled in with today's date"
else
  _fail "scaffold-aggregate-design: date filled in with today's date" "date placeholder not replaced"
fi

if grep -qE '^## Aggregate: \[Name\]$' "$OUT"; then
  _pass "scaffold-aggregate-design: the repeatable Aggregate section stub is preserved for filling in"
else
  _fail "scaffold-aggregate-design: the repeatable Aggregate section stub is preserved for filling in" "expected the [Name] placeholder heading to survive scaffolding"
fi

# A Bounded Context name containing an ampersand (sed replacement-special)
# must not corrupt the output.
OUT2="$("$SCAFFOLD" acme "Storage & Retrieval" 2>&1)"
if grep -q "^bounded-context: Storage & Retrieval$" "$OUT2"; then
  _pass "scaffold-aggregate-design: a context name containing an ampersand is escaped correctly, not corrupted"
else
  _fail "scaffold-aggregate-design: a context name containing an ampersand is escaped correctly, not corrupted" "got: $(grep '^bounded-context:' "$OUT2" 2>/dev/null || echo 'no bounded-context line found')"
fi

# Missing required arg -> non-zero exit
if ! "$SCAFFOLD" acme >/dev/null 2>&1; then
  _pass "scaffold-aggregate-design: missing bounded-context argument exits non-zero"
else
  _fail "scaffold-aggregate-design: missing bounded-context argument exits non-zero" "script exited 0 with only one argument"
fi

smoke_test_summary
