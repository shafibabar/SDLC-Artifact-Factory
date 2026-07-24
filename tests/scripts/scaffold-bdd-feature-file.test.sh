#!/bin/bash
# Tests skills/bdd-feature-file/scripts/scaffold-bdd-feature-file.sh — a
# skill-owned script exercised directly with CLI args, not smoke_test_script's
# stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/bdd-feature-file/scripts/scaffold-bdd-feature-file.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" "Classify a data asset")"
if [ "$OUT" = "features/classify_a_data_asset.feature" ] && [ -f "$OUT" ]; then
  _pass "scaffold-bdd-feature-file: writes to the expected path"
else
  _fail "scaffold-bdd-feature-file: writes to the expected path" "got: $OUT"
fi

if grep -q "^Feature: Classify a data asset$" "$OUT" && grep -q "^# features/classify_a_data_asset.feature$" "$OUT"; then
  _pass "scaffold-bdd-feature-file: feature title and comment-header path filled in correctly"
else
  _fail "scaffold-bdd-feature-file: feature title and comment-header path filled in correctly" "placeholders not replaced as expected"
fi

if grep -q "# happy" "$OUT" && grep -q "# negative" "$OUT" && grep -q "# edge" "$OUT"; then
  _pass "scaffold-bdd-feature-file: all three Golden Triangle tags present in the generated file"
else
  _fail "scaffold-bdd-feature-file: all three Golden Triangle tags present in the generated file" "expected all of # happy / # negative / # edge"
fi

# Refuse to overwrite an existing file.
if ! "$SCAFFOLD" "Classify a data asset" >/dev/null 2>&1; then
  _pass "scaffold-bdd-feature-file: refuses to overwrite an existing file"
else
  _fail "scaffold-bdd-feature-file: refuses to overwrite an existing file" "script exited 0 on a second call with the same title"
fi

# A title containing a slash (sed-special) must not corrupt the output.
OUT2="$("$SCAFFOLD" "Handle read/write conflicts" 2>&1)"
if grep -q "^Feature: Handle read/write conflicts$" "$OUT2"; then
  _pass "scaffold-bdd-feature-file: a title containing a slash is escaped correctly, not corrupted"
else
  _fail "scaffold-bdd-feature-file: a title containing a slash is escaped correctly, not corrupted" "got: $(grep '^Feature:' "$OUT2" 2>/dev/null || echo 'no Feature line found')"
fi

# Missing required arg -> non-zero exit.
if ! "$SCAFFOLD" >/dev/null 2>&1; then
  _pass "scaffold-bdd-feature-file: missing feature-title argument exits non-zero"
else
  _fail "scaffold-bdd-feature-file: missing feature-title argument exits non-zero" "script exited 0 with no arguments"
fi

smoke_test_summary
