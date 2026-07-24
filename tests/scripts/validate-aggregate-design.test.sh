#!/bin/bash
# Tests skills/aggregate-design/scripts/validate-aggregate-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/aggregate-design/scripts/validate-aggregate-design.sh"
SCAFFOLD="$REPO_ROOT/skills/aggregate-design/scripts/scaffold-aggregate-design.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has Root Entity, Invariants, Entities, and Value
# Objects all unfilled -- must fail exactly those four.
FRESH="$("$SCAFFOLD" acme Classification)"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-aggregate-design: a fresh scaffold with unfilled fields fails"
else
  _fail "validate-aggregate-design: a fresh scaffold with unfilled fields fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "4 check(s) failed"; then
  _pass "validate-aggregate-design: reports exactly 4 failed checks on a fresh scaffold"
else
  _fail "validate-aggregate-design: reports exactly 4 failed checks on a fresh scaffold" "expected '4 check(s) failed'"
fi

if echo "$OUTPUT" | grep -q "PASS: at least one '## Aggregate:' section present" && echo "$OUTPUT" | grep -q "PASS: frontmatter has 'owner'"; then
  _pass "validate-aggregate-design: does not false-fail checks that are already correct on a fresh scaffold"
else
  _fail "validate-aggregate-design: does not false-fail checks that are already correct on a fresh scaffold" "expected the section-presence and frontmatter checks to pass"
fi

# Filling in Root Entity, one Invariant, and both tables makes it pass.
sed -i 's/\[Name and responsibility\]/DataAsset -- classifies files by sensitivity/' "$FRESH"
sed -i 's/1\. \[Rule that must always be true\].*/1. A DataAsset may only be marked Restricted if its storage source is confirmed active. -- Q1: yes Q2: no Q3: no/' "$FRESH"
sed -i '/### Entities/,/^$/{/|---|---|---|---|/a\
| ExtractedEntity | local, scoped to root | text span, confidence | outside code never fetches one independently |
}' "$FRESH"
sed -i '/### Value Objects/,/^$/{/|---|---|---|---|/a\
| SensitivityLevel | level enum | value equality | yes |
}' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-aggregate-design: filling in the four fields passes all checks"
else
  _fail "validate-aggregate-design: filling in the four fields passes all checks" "expected exit 0 once all fields are filled in"
fi

# Adding a Cross-Aggregate Relationship row with a Go pointer reference
# (a live-object-reference smell) must fail that specific check.
sed -i '/### Cross-Aggregate Relationships/,/^$/{/|---|---|---|---|---|/a\
| StorageSource | Y | N | keep separate | *StorageSource pointer |
}' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: Cross-Aggregate Relationships reference by ID, not a Go pointer"; then
  _pass "validate-aggregate-design: catches a Go pointer reference in Cross-Aggregate Relationships"
else
  _fail "validate-aggregate-design: catches a Go pointer reference in Cross-Aggregate Relationships" "expected a FAIL line for the pointer-reference check"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-aggregate-design: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-aggregate-design: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
