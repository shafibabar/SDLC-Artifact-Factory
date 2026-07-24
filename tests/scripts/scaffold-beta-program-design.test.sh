#!/bin/bash
# Tests skills/beta-program-design/scripts/scaffold-beta-program-design.sh — a
# skill-owned script exercised directly with CLI args, not smoke_test_script's
# stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/beta-program-design/scripts/scaffold-beta-program-design.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme classification-pipeline)"
if [ "$OUT" = "artifacts/acme/customer-validation/beta-program/classification-pipeline.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-beta-program-design: writes to the expected path"
else
  _fail "scaffold-beta-program-design: writes to the expected path" "got: $OUT"
fi

if grep -q "^name: beta-program-acme-classification-pipeline$" "$OUT" \
   && grep -q "^product: acme$" "$OUT" \
   && grep -q "^# Beta Program — acme classification-pipeline$" "$OUT"; then
  _pass "scaffold-beta-program-design: name, product, and heading filled in correctly"
else
  _fail "scaffold-beta-program-design: name, product, and heading filled in correctly" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-beta-program-design: date filled in with today's date"
else
  _fail "scaffold-beta-program-design: date filled in with today's date" "date placeholder not replaced"
fi

# Refuse to overwrite an existing file.
if ! "$SCAFFOLD" acme classification-pipeline >/dev/null 2>&1; then
  _pass "scaffold-beta-program-design: refuses to overwrite an existing file"
else
  _fail "scaffold-beta-program-design: refuses to overwrite an existing file" "script exited 0 on a second call with the same args"
fi

# A release-slice containing a slash (sed-special) must not corrupt the output.
OUT2="$("$SCAFFOLD" acme "Read/write conflicts v2" 2>&1)"
if grep -q "^# Beta Program — acme Read/write conflicts v2$" "$OUT2"; then
  _pass "scaffold-beta-program-design: a release-slice containing a slash is escaped correctly, not corrupted"
else
  _fail "scaffold-beta-program-design: a release-slice containing a slash is escaped correctly, not corrupted" "got: $(grep '^# Beta Program' "$OUT2" 2>/dev/null || echo 'no heading found')"
fi

# Missing required arg -> non-zero exit.
if ! "$SCAFFOLD" acme >/dev/null 2>&1; then
  _pass "scaffold-beta-program-design: missing release-slice argument exits non-zero"
else
  _fail "scaffold-beta-program-design: missing release-slice argument exits non-zero" "script exited 0 with only one argument"
fi

smoke_test_summary
