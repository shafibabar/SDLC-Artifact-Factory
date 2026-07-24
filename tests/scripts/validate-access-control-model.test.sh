#!/bin/bash
# Tests skills/access-control-model/scripts/validate-access-control-model.sh —
# a skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/access-control-model/scripts/validate-access-control-model.sh"
SCAFFOLD="$REPO_ROOT/skills/access-control-model/scripts/scaffold-access-control-model.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold has all three key tables empty -- must fail exactly those
# three, not the frontmatter checks (which are already correct).
FRESH="$("$SCAFFOLD" acme)"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-access-control-model: a fresh scaffold with empty tables fails"
else
  _fail "validate-access-control-model: a fresh scaffold with empty tables fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "3 check(s) failed" && echo "$OUTPUT" | grep -q "PASS: frontmatter has 'name'"; then
  _pass "validate-access-control-model: fails exactly the 3 empty tables, not the correct frontmatter"
else
  _fail "validate-access-control-model: fails exactly the 3 empty tables, not the correct frontmatter" "expected 3 failures and passing frontmatter checks"
fi

# Filling in all three tables with a real data row makes it pass entirely.
sed -i '/## Domain Primitives/,/^$/{/|---|---|---|/a\
| TenantID | NewTenantID | non-nil UUID |
}' "$FRESH"
sed -i '/## Policies/,/^$/{/|---|---|---|---|/a\
| P1 | Tenant isolation | subject.tenant_id, resource.tenant_id | allow/deny |
}' "$FRESH"
sed -i '/## Per-Aggregate Trust-Boundary Decisions/,/^$/{/|---|---|---|---|/a\
| DataAsset | yes | yes | yes |
}' "$FRESH"

if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-access-control-model: filling in all three tables passes all checks"
else
  _fail "validate-access-control-model: filling in all three tables passes all checks" "expected exit 0 once all tables have data"
fi

# A doc missing a frontmatter field entirely must fail that specific check.
cat > "$SCRATCH_DIR/missing-field.md" <<'EOF'
---
name: access-control-model
product: acme
version: 1.0.0
phase: design
owner: security-architect
---

# Access Control Model

## Domain Primitives
| Type | Constructor | Invariant enforced |
|---|---|---|
| TenantID | NewTenantID | non-nil UUID |

## Policies
| Policy ID | Rule (natural language) | Attributes evaluated | Decision |
|---|---|---|---|
| P1 | Tenant isolation | subject.tenant_id | allow/deny |

## Per-Aggregate Trust-Boundary Decisions
| Aggregate | Multi-tenant reachable? | Authorization required? | Expressed as domain concept? |
|---|---|---|---|
| DataAsset | yes | yes | yes |
EOF

OUTPUT2="$("$VALIDATE" "$SCRATCH_DIR/missing-field.md" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: frontmatter has 'created'" && echo "$OUTPUT2" | grep -q "1 check(s) failed"; then
  _pass "validate-access-control-model: catches a missing frontmatter field without false-failing the complete tables"
else
  _fail "validate-access-control-model: catches a missing frontmatter field without false-failing the complete tables" "expected exactly 1 failure naming the missing 'created' field"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-access-control-model: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-access-control-model: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
