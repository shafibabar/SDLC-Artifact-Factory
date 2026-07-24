#!/bin/bash
# Tests skills/alerting-rules-design/scripts/validate-alerting-rules-design.sh —
# a skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/alerting-rules-design/scripts/validate-alerting-rules-design.sh"
SCAFFOLD="$REPO_ROOT/skills/alerting-rules-design/scripts/scaffold-alerting-rules-design.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has every table empty -- must fail the Review Log
# data-row check and both Alert Inventory severity checks.
FRESH="$("$SCAFFOLD" acme-widgets)"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-alerting-rules-design: a fresh scaffold with empty tables fails"
else
  _fail "validate-alerting-rules-design: a fresh scaffold with empty tables fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "3 check(s) failed"; then
  _pass "validate-alerting-rules-design: reports exactly 3 failed checks on a fresh scaffold"
else
  _fail "validate-alerting-rules-design: reports exactly 3 failed checks on a fresh scaffold" "expected '3 check(s) failed', got: $(echo "$OUTPUT" | tail -1)"
fi

if echo "$OUTPUT" | grep -q "PASS: '## Alert Inventory' section present" && echo "$OUTPUT" | grep -q "PASS: frontmatter has 'owner'"; then
  _pass "validate-alerting-rules-design: does not false-fail checks that are already correct on a fresh scaffold"
else
  _fail "validate-alerting-rules-design: does not false-fail checks that are already correct on a fresh scaffold" "expected the section-presence and frontmatter checks to pass"
fi

# Filling in an Alert Inventory row (page + ticket) and a Review Log row
# makes it pass. Insert after each table's separator row (not the header),
# so row order stays [header, separator, data...] as validate expects.
sed -i '/^## Alert Inventory$/,/^$/{/^|---|---|---|---|---|$/a\
| FastBurn | test-slo | page | 1h+5m, 14.4x | runbooks/test.md |\
| Trickle | test-slo | ticket | 3d+6h, 1x | runbooks/test.md |
}' "$FRESH"
sed -i '/^## Review Log$/,/^$/{/^|---|---|---|---|---|---|$/a\
| 2026-07-24 | FastBurn | 1 | yes | no | keep |
}' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-alerting-rules-design: filling in Alert Inventory and Review Log rows passes all checks"
else
  _fail "validate-alerting-rules-design: filling in Alert Inventory and Review Log rows passes all checks" "expected exit 0 once required rows are filled in"
fi

# Removing the Toil column from the Review Log header must fail that
# specific check without regressing the others.
sed -i 's/| Date | Alert | Fired count | Actioned? | Toil (repeat manual fix?) | Decision (keep\/tune\/delete\/automate) |/| Date | Alert | Fired count | Actioned? | Decision (keep\/tune\/delete\/automate) |/' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: '## Review Log' header has a Toil column"; then
  _pass "validate-alerting-rules-design: catches a Review Log missing its Toil column"
else
  _fail "validate-alerting-rules-design: catches a Review Log missing its Toil column" "expected a FAIL line for the missing Toil column"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-alerting-rules-design: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-alerting-rules-design: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
