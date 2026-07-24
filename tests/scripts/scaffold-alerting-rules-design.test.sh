#!/bin/bash
# Tests skills/alerting-rules-design/scripts/scaffold-alerting-rules-design.sh —
# a skill-owned script exercised directly with a CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/alerting-rules-design/scripts/scaffold-alerting-rules-design.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme-widgets)"
if [ "$OUT" = "artifacts/acme-widgets/deploy/alerting-rules-design.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-alerting-rules-design: writes to the expected path"
else
  _fail "scaffold-alerting-rules-design: writes to the expected path" "got: $OUT"
fi

if grep -q "^name: alerting-rules-design-acme-widgets$" "$OUT" \
  && grep -q "^product: acme-widgets$" "$OUT" \
  && grep -q "^# Alerting Rules Design — Acme Widgets$" "$OUT"; then
  _pass "scaffold-alerting-rules-design: product placeholders resolved, including the title-cased H1"
else
  _fail "scaffold-alerting-rules-design: product placeholders resolved, including the title-cased H1" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-alerting-rules-design: date filled in with today's date"
else
  _fail "scaffold-alerting-rules-design: date filled in with today's date" "date placeholder not replaced"
fi

if grep -qE '^## Alert Inventory$' "$OUT" && grep -qE '^## Review Log$' "$OUT"; then
  _pass "scaffold-alerting-rules-design: Output Format sections are preserved for filling in"
else
  _fail "scaffold-alerting-rules-design: Output Format sections are preserved for filling in" "expected Alert Inventory and Review Log headings to survive scaffolding"
fi

# A product name containing an ampersand (sed replacement-special) must not
# corrupt the output.
OUT2="$("$SCAFFOLD" "acme & co" 2>&1)"
if grep -q "^product: acme & co$" "$OUT2"; then
  _pass "scaffold-alerting-rules-design: a product name containing an ampersand is escaped correctly, not corrupted"
else
  _fail "scaffold-alerting-rules-design: a product name containing an ampersand is escaped correctly, not corrupted" "got: $(grep '^product:' "$OUT2" 2>/dev/null || echo 'no product line found')"
fi

# Refuses to overwrite an existing output file.
if ! "$SCAFFOLD" acme-widgets >/dev/null 2>&1; then
  _pass "scaffold-alerting-rules-design: refuses to overwrite an existing design doc"
else
  _fail "scaffold-alerting-rules-design: refuses to overwrite an existing design doc" "script exited 0 when the output file already existed"
fi

# Missing required arg -> non-zero exit
if ! "$SCAFFOLD" >/dev/null 2>&1; then
  _pass "scaffold-alerting-rules-design: missing product argument exits non-zero"
else
  _fail "scaffold-alerting-rules-design: missing product argument exits non-zero" "script exited 0 with no arguments"
fi

smoke_test_summary
