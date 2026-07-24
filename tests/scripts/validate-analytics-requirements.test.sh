#!/bin/bash
# Tests skills/analytics-requirements/scripts/validate-analytics-requirements.sh —
# a skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/analytics-requirements/scripts/validate-analytics-requirements.sh"
SCAFFOLD="$REPO_ROOT/skills/analytics-requirements/scripts/scaffold-analytics-requirements.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has both key tables empty -- must fail exactly those two,
# not the frontmatter or section-presence checks (which are already correct).
FRESH="$("$SCAFFOLD" acme)"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-analytics-requirements: a fresh scaffold with empty tables fails"
else
  _fail "validate-analytics-requirements: a fresh scaffold with empty tables fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "2 check(s) failed" && echo "$OUTPUT" | grep -q "PASS: frontmatter has 'name'"; then
  _pass "validate-analytics-requirements: fails exactly the 2 empty tables, not the correct frontmatter"
else
  _fail "validate-analytics-requirements: fails exactly the 2 empty tables, not the correct frontmatter" "expected 2 failures and passing frontmatter checks"
fi

# Filling in both tables with a real data row makes it pass entirely.
sed -i '/## Requirements Table/,/^$/{/|---|---|---|---|---|---|/a\
| Which sources have gaps? | Prioritise remediation | Count of open gaps | compliance_gap_summary | 15 min | data-engineer |
}' "$FRESH"
sed -i '/## Vanity-Metric Review/,/^$/{/|---|---|---|---|---|---|---|---|/a\
| Open gap count | yes | yes | yes | no | yes | yes | accepted |
}' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-analytics-requirements: filling in both tables passes all checks"
else
  _fail "validate-analytics-requirements: filling in both tables passes all checks" "expected exit 0 once both tables have data"
fi

# A doc missing a required Output Format section entirely must fail that
# specific check without regressing the others.
sed -i '/## Deferred \/ Rejected Requests/,$d' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: '## Deferred / Rejected Requests' section present" && echo "$OUTPUT2" | grep -q "1 check(s) failed"; then
  _pass "validate-analytics-requirements: catches a missing Output Format section without false-failing the filled tables"
else
  _fail "validate-analytics-requirements: catches a missing Output Format section without false-failing the filled tables" "expected exactly 1 failure naming the missing section"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-analytics-requirements: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-analytics-requirements: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
