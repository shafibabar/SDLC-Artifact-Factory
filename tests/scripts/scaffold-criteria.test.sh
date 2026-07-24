#!/bin/bash
# Tests skills/acceptance-criteria/scripts/scaffold-criteria.sh — a
# skill-owned script exercised directly with CLI args, not smoke_test_script's
# stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/acceptance-criteria/scripts/scaffold-criteria.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme 042 "Classify a newly connected file")"
if [ "$OUT" = "artifacts/acme/ideate/acceptance-criteria/US-042-classify-a-newly-connected-file.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-criteria: writes to the expected path"
else
  _fail "scaffold-criteria: writes to the expected path" "got: $OUT"
fi

if grep -q "^story-id: US-042$" "$OUT" && grep -q "^# Acceptance Criteria: US-042 — Classify a newly connected file$" "$OUT"; then
  _pass "scaffold-criteria: story-id and heading filled in correctly"
else
  _fail "scaffold-criteria: story-id and heading filled in correctly" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-criteria: date filled in with today's date"
else
  _fail "scaffold-criteria: date filled in with today's date" "date placeholder not replaced"
fi

# This is the real bug caught while building this script: a naive global
# replace of "[ID]" would also overwrite the unrelated "EM-[ID]" example-map
# placeholder in the Derived From section, silently inventing a fake
# traceability link. The fix scopes the replacement to "US-[ID]" specifically.
if grep -q "EM-\[ID\]" "$OUT"; then
  _pass "scaffold-criteria: the unrelated EM-[ID] placeholder is left untouched"
else
  _fail "scaffold-criteria: the unrelated EM-[ID] placeholder is left untouched" "EM-[ID] was unexpectedly modified -- the US-[ID]/EM-[ID] replacement-scope bug may have regressed"
fi

# A title containing a slash (sed-special) must not corrupt the output
OUT2="$("$SCAFFOLD" acme 043 "Handle read/write conflicts" 2>&1)"
if grep -q "^# Acceptance Criteria: US-043 — Handle read/write conflicts$" "$OUT2"; then
  _pass "scaffold-criteria: a title containing a slash is escaped correctly, not corrupted"
else
  _fail "scaffold-criteria: a title containing a slash is escaped correctly, not corrupted" "got: $(grep '^#' "$OUT2" 2>/dev/null || echo 'no heading found')"
fi

# Missing required args -> non-zero exit
if ! "$SCAFFOLD" acme 044 >/dev/null 2>&1; then
  _pass "scaffold-criteria: missing story-title argument exits non-zero"
else
  _fail "scaffold-criteria: missing story-title argument exits non-zero" "script exited 0 with only two arguments"
fi

smoke_test_summary
