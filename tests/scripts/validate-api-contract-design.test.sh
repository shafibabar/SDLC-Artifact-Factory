#!/bin/bash
# Tests skills/api-contract-design/scripts/validate-api-contract-design.sh —
# a skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/api-contract-design/scripts/validate-api-contract-design.sh"
SCAFFOLD="$REPO_ROOT/skills/api-contract-design/scripts/scaffold-api-contract-design.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold's Endpoints table has only the unfilled placeholder row --
# must fail exactly that one check, not the frontmatter/section checks.
FRESH="$("$SCAFFOLD" acme "Compliance Engine")"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-api-contract-design: a fresh scaffold with only the placeholder row fails"
else
  _fail "validate-api-contract-design: a fresh scaffold with only the placeholder row fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "1 check(s) failed" && echo "$OUTPUT" | grep -q "PASS: frontmatter has 'openapi-spec'"; then
  _pass "validate-api-contract-design: fails exactly the placeholder-row check, not the correct frontmatter"
else
  _fail "validate-api-contract-design: fails exactly the placeholder-row check, not the correct frontmatter" "expected 1 failure and passing frontmatter checks"
fi

# Replacing the placeholder row with a real endpoint makes it pass entirely.
sed -i 's/| \[GET\/POST\/PUT\/PATCH\/DELETE\] | \[\/v1\/resource-path\] | \[Command or Read Model name it maps to\] | \[BearerAuth \/ none\] | \[Yes — Idempotency-Key supported \/ No — safe method\] |/| GET | \/v1\/compliance-gaps | ComplianceGapSummary Read Model | BearerAuth | No — safe method |/' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-api-contract-design: replacing the placeholder row with a real endpoint passes all checks"
else
  _fail "validate-api-contract-design: replacing the placeholder row with a real endpoint passes all checks" "expected exit 0 once a real endpoint row is present"
fi

# A doc missing a required Output Format section entirely must fail that
# specific check without regressing the others.
sed -i '/## Consumer Registry/,$d' "$FRESH"
OUTPUT2="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: '## Consumer Registry' section present" && echo "$OUTPUT2" | grep -q "1 check(s) failed"; then
  _pass "validate-api-contract-design: catches a missing Output Format section without false-failing the filled Endpoints table"
else
  _fail "validate-api-contract-design: catches a missing Output Format section without false-failing the filled Endpoints table" "expected exactly 1 failure naming the missing section"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-api-contract-design: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-api-contract-design: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
