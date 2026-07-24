#!/bin/bash
# Tests skills/access-control-model/scripts/scaffold-access-control-model.sh —
# a skill-owned script exercised directly with CLI args.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/access-control-model/scripts/scaffold-access-control-model.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme)"
if [ "$OUT" = "artifacts/acme/design/access-control-model.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-access-control-model: writes to the expected path"
else
  _fail "scaffold-access-control-model: writes to the expected path" "got: $OUT"
fi

if grep -q "^product: acme$" "$OUT"; then
  _pass "scaffold-access-control-model: product name filled in correctly"
else
  _fail "scaffold-access-control-model: product name filled in correctly" "placeholder not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-access-control-model: date filled in with today's date"
else
  _fail "scaffold-access-control-model: date filled in with today's date" "date placeholder not replaced"
fi

# All six required table headings must survive the scaffold untouched.
for section in "## Attribute Schema" "## Domain Primitives" "## Policies" "## Role → Permission Mapping" "## Permission Registry" "## Per-Aggregate Trust-Boundary Decisions" "## Go Policy Interface" "## Enforcement Locations"; do
  if grep -qF "$section" "$OUT"; then
    :
  else
    _fail "scaffold-access-control-model: all 8 sections present" "missing section: $section"
  fi
done
if grep -qF "## Enforcement Locations" "$OUT"; then
  _pass "scaffold-access-control-model: all 8 sections present"
fi

# A product name containing an ampersand (sed replacement-special) must not
# corrupt the output -- sed's replacement side treats & as "the whole match".
OUT2="$("$SCAFFOLD" "acme-r&d" 2>&1)"
if grep -q "^product: acme-r&d$" "$OUT2"; then
  _pass "scaffold-access-control-model: a product name containing an ampersand is escaped correctly, not corrupted"
else
  _fail "scaffold-access-control-model: a product name containing an ampersand is escaped correctly, not corrupted" "got: $(grep '^product:' "$OUT2" 2>/dev/null || echo 'no product line found')"
fi

# Missing required arg -> non-zero exit
if ! "$SCAFFOLD" >/dev/null 2>&1; then
  _pass "scaffold-access-control-model: missing product argument exits non-zero"
else
  _fail "scaffold-access-control-model: missing product argument exits non-zero" "script exited 0 with no arguments"
fi

smoke_test_summary
