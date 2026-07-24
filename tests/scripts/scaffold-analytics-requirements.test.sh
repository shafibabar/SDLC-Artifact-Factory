#!/bin/bash
# Tests skills/analytics-requirements/scripts/scaffold-analytics-requirements.sh —
# a skill-owned script exercised directly with a CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/analytics-requirements/scripts/scaffold-analytics-requirements.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme)"
if [ "$OUT" = "artifacts/acme/data/analytics-requirements.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-analytics-requirements: writes to the expected path"
else
  _fail "scaffold-analytics-requirements: writes to the expected path" "got: $OUT"
fi

if grep -q "^product: acme$" "$OUT"; then
  _pass "scaffold-analytics-requirements: product name filled in correctly"
else
  _fail "scaffold-analytics-requirements: product name filled in correctly" "placeholder not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-analytics-requirements: date filled in with today's date"
else
  _fail "scaffold-analytics-requirements: date filled in with today's date" "date placeholder not replaced"
fi

for section in "## Requirements Table" "## Vanity-Metric Review" "## OKR / Decision Traceability" "## Deferred / Rejected Requests"; do
  if grep -qF "$section" "$OUT"; then
    :
  else
    _fail "scaffold-analytics-requirements: all 4 Output Format sections present" "missing section: $section"
  fi
done
if grep -qF "## Deferred / Rejected Requests" "$OUT"; then
  _pass "scaffold-analytics-requirements: all 4 Output Format sections present"
fi

if grep -qF "Understandable?" "$OUT"; then
  _pass "scaffold-analytics-requirements: Vanity-Metric Review table includes the Understandable? column"
else
  _fail "scaffold-analytics-requirements: Vanity-Metric Review table includes the Understandable? column" "expected Understandable? column header in the scaffolded table"
fi

# A product name containing an ampersand (sed replacement-special) must not
# corrupt the output -- sed's replacement side treats & as "the whole match".
OUT2="$("$SCAFFOLD" "acme-r&d" 2>&1)"
if grep -q "^product: acme-r&d$" "$OUT2"; then
  _pass "scaffold-analytics-requirements: a product name containing an ampersand is escaped correctly, not corrupted"
else
  _fail "scaffold-analytics-requirements: a product name containing an ampersand is escaped correctly, not corrupted" "got: $(grep '^product:' "$OUT2" 2>/dev/null || echo 'no product line found')"
fi

# Refuses to overwrite an existing output file.
if ! "$SCAFFOLD" acme >/dev/null 2>&1; then
  _pass "scaffold-analytics-requirements: refuses to overwrite an existing requirements doc"
else
  _fail "scaffold-analytics-requirements: refuses to overwrite an existing requirements doc" "script exited 0 when the output file already existed"
fi

# Missing required arg -> non-zero exit
if ! "$SCAFFOLD" >/dev/null 2>&1; then
  _pass "scaffold-analytics-requirements: missing product argument exits non-zero"
else
  _fail "scaffold-analytics-requirements: missing product argument exits non-zero" "script exited 0 with no arguments"
fi

smoke_test_summary
