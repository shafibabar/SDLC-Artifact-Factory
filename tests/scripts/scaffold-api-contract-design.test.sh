#!/bin/bash
# Tests skills/api-contract-design/scripts/scaffold-api-contract-design.sh —
# a skill-owned script exercised directly with CLI args.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/api-contract-design/scripts/scaffold-api-contract-design.sh"

cd "$SCRATCH_DIR"

OUT="$("$SCAFFOLD" acme "Compliance Engine")"
if [ "$OUT" = "artifacts/acme/design/compliance-engine/api-contract-summary.md" ] && [ -f "$OUT" ]; then
  _pass "scaffold-api-contract-design: writes to the expected path"
else
  _fail "scaffold-api-contract-design: writes to the expected path" "got: $OUT"
fi

if grep -q "^product: acme$" "$OUT" && grep -q "^service: Compliance Engine$" "$OUT" && grep -q "^# API Contract Summary: Compliance Engine$" "$OUT"; then
  _pass "scaffold-api-contract-design: product/service placeholders resolved, all occurrences"
else
  _fail "scaffold-api-contract-design: product/service placeholders resolved, all occurrences" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT"; then
  _pass "scaffold-api-contract-design: date filled in with today's date"
else
  _fail "scaffold-api-contract-design: date filled in with today's date" "date placeholder not replaced"
fi

if grep -q "^openapi-spec: artifacts/acme/design/compliance-engine/openapi.yaml$" "$OUT"; then
  _pass "scaffold-api-contract-design: openapi-spec path resolved with both product and service-slug tokens"
else
  _fail "scaffold-api-contract-design: openapi-spec path resolved with both product and service-slug tokens" "got: $(grep '^openapi-spec:' "$OUT" 2>/dev/null || echo 'no openapi-spec line found')"
fi

for section in "## Endpoints" "## Breaking Change Log" "## Consumer Registry"; do
  if grep -qF "$section" "$OUT"; then
    :
  else
    _fail "scaffold-api-contract-design: all 3 Output Format sections present" "missing section: $section"
  fi
done
if grep -qF "## Consumer Registry" "$OUT"; then
  _pass "scaffold-api-contract-design: all 3 Output Format sections present"
fi

# A service name containing an ampersand (sed replacement-special) must not
# corrupt the output.
OUT2="$("$SCAFFOLD" acme "Reporting & Analytics" 2>&1)"
if grep -q "^service: Reporting & Analytics$" "$OUT2"; then
  _pass "scaffold-api-contract-design: a service name containing an ampersand is escaped correctly, not corrupted"
else
  _fail "scaffold-api-contract-design: a service name containing an ampersand is escaped correctly, not corrupted" "got: $(grep '^service:' "$OUT2" 2>/dev/null || echo 'no service line found')"
fi

# Refuses to overwrite an existing output file.
if ! "$SCAFFOLD" acme "Compliance Engine" >/dev/null 2>&1; then
  _pass "scaffold-api-contract-design: refuses to overwrite an existing contract summary"
else
  _fail "scaffold-api-contract-design: refuses to overwrite an existing contract summary" "script exited 0 when the output file already existed"
fi

# Missing required arg -> non-zero exit
if ! "$SCAFFOLD" acme >/dev/null 2>&1; then
  _pass "scaffold-api-contract-design: missing service-name argument exits non-zero"
else
  _fail "scaffold-api-contract-design: missing service-name argument exits non-zero" "script exited 0 with only one argument"
fi

smoke_test_summary
