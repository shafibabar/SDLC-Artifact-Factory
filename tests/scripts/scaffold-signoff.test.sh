#!/bin/bash
# Tests skills/acceptance-sign-off/scripts/scaffold-signoff.sh — a
# skill-owned script exercised directly with CLI args.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/acceptance-sign-off/scripts/scaffold-signoff.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme "2026-08 classification v2")"
if [ "$OUT" = "artifacts/acme/customer-validation/sign-off/2026-08-classification-v2.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-signoff: writes to the expected path"
else
  _fail "scaffold-signoff: writes to the expected path" "got: $OUT"
fi

# The name: field must get the machine-friendly SLUG, not the raw
# human-readable text (which contains spaces) -- this is the exact
# distinction the script has to get right since both the name: field and
# the heading share the same [release-slice] placeholder token in the
# raw template.
if grep -q "^name: acceptance-sign-off-2026-08-classification-v2$" "$OUT"; then
  _pass "scaffold-signoff: name: field gets the slug, not raw text with spaces"
else
  _fail "scaffold-signoff: name: field gets the slug, not raw text with spaces" "expected slugified name: field"
fi

if grep -q "^release-slice: 2026-08 classification v2$" "$OUT" && grep -q "^# Acceptance Sign-Off — 2026-08 classification v2$" "$OUT"; then
  _pass "scaffold-signoff: release-slice field and heading get the human-readable text"
else
  _fail "scaffold-signoff: release-slice field and heading get the human-readable text" "expected raw text preserved in these two spots"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-signoff: date filled in with today's date"
else
  _fail "scaffold-signoff: date filled in with today's date" "date placeholder not replaced"
fi

CHECKLIST_ITEMS="$(grep -cE '^\s*- \[ \]' "$OUT")"
if [ "$CHECKLIST_ITEMS" -eq 8 ]; then
  _pass "scaffold-signoff: full 8-item checklist copied in unchecked"
else
  _fail "scaffold-signoff: full 8-item checklist copied in unchecked" "expected 8 unchecked items, found $CHECKLIST_ITEMS"
fi

# A release-slice containing a slash (sed-special) must not corrupt the output
OUT2="$("$SCAFFOLD" acme "2026-08 read/write conflicts" 2>&1)"
if grep -q "^# Acceptance Sign-Off — 2026-08 read/write conflicts$" "$OUT2"; then
  _pass "scaffold-signoff: a release-slice containing a slash is escaped correctly, not corrupted"
else
  _fail "scaffold-signoff: a release-slice containing a slash is escaped correctly, not corrupted" "got: $(grep '^#' "$OUT2" 2>/dev/null || echo 'no heading found')"
fi

# Missing required args -> non-zero exit
if ! "$SCAFFOLD" acme >/dev/null 2>&1; then
  _pass "scaffold-signoff: missing release-slice argument exits non-zero"
else
  _fail "scaffold-signoff: missing release-slice argument exits non-zero" "script exited 0 with only one argument"
fi

smoke_test_summary
