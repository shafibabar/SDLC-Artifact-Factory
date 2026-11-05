#!/bin/bash
# Tests skills/context-map-patterns/scripts/validate-pattern-rationale.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/context-map-patterns/scripts/validate-pattern-rationale.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-pattern-rationale: $1"
  else
    _fail "validate-pattern-rationale: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: context-map
product: orchardly
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-02
summary: Orchardly context map.
---

## Contexts

### Harvest Planning

| Field | Value |
|---|---|
| **Owner** | domain-modeler (agent-built) |

### Packhouse

| Field | Value |
|---|---|
| **Owner** | domain-modeler (agent-built) |

## Relationships

| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| Harvest Planning | Packhouse | Customer/Supplier | Packhouse needs picking forecasts on its terms; Conformist rejected because its grading rules shape what is sent | Consumer-driven contract tests from Packhouse, run in Harvest Planning's pipeline |
| Weather Feed | Harvest Planning | Anticorruption Layer | Harvest Planning is Core and the feed's "frost risk" means a different threshold; Conformist rejected | Integration tests against the feed |
| Card Provider | Packhouse | Conformist | Clean vendor model and payments aren't Core; Anticorruption Layer rejected as a one-to-one copy | None; note the API version |
EOF
expect "a complete rationale passes and counts patterns" good.md 0 "INFO: 1 Anticorruption Layer, 1 Conformist, 1 Customer/Supplier"

sed 's/| Customer\/Supplier | Packhouse needs/| Customer\/Supplier, Partnership | Packhouse needs/' good.md > two.md
expect "two patterns on one line fails" two.md 1 "FAIL: line Harvest Planning → Packhouse: one pattern from the catalogue"

sed 's/; Conformist rejected because its grading rules shape what is sent |/ |/' good.md > norej.md
expect "a reason with no rejected alternative fails" norej.md 1 "FAIL: line Harvest Planning → Packhouse: the reason names a pattern considered and rejected"

sed "s/| Consumer-driven contract tests from Packhouse, run in Harvest Planning's pipeline |/| Weekly sync call |/" good.md > nocdc.md
expect "Customer/Supplier without contract tests fails" nocdc.md 1 "FAIL: line Harvest Planning → Packhouse: Customer/Supplier carries consumer-driven contract tests"

sed 's/| None; note the API version |/| |/' good.md > nocontract.md
expect "an empty contract fails" nocontract.md 1 "FAIL: line Card Provider → Packhouse: the contract is filled in"

sed "s/| Customer\/Supplier | Packhouse needs picking forecasts on its terms; Conformist rejected because its grading rules shape what is sent | Consumer-driven contract tests from Packhouse, run in Harvest Planning's pipeline |/| Partnership | Tightly coupled; Customer\/Supplier rejected | Joint planning |/" good.md > partner.md
expect "Partnership with one owner on both sides fails" partner.md 1 "FAIL: line Harvest Planning → Packhouse: Partnership has two different owners"

sed 's/| Harvest Planning is Core and the feed.s "frost risk" means a different threshold; Conformist rejected |/| Our rule: every external system; Conformist rejected |/' good.md > aclwhy.md
expect "an unjustified Anticorruption Layer warns" aclwhy.md 0 "WARN: line Weather Feed → Harvest Planning: an Anticorruption Layer whose reason gives no justifying condition"

sed 's/| Customer\/Supplier | Packhouse needs/| Open Host Service | Packhouse needs/' good.md | sed "s/| Consumer-driven contract tests from Packhouse, run in Harvest Planning's pipeline |/| Contract tests for Packhouse |/" > ohs.md
expect "Open Host Service without versioning fails" ohs.md 1 "FAIL: line Harvest Planning → Packhouse: Open Host Service carries versioned protocol discipline"

awk '/^\| Upstream/{sub(/ Contract \|$/,"")} /^\|---/{sub(/---\|$/,"")} {print}' good.md > nocol.md
expect "no Contract column fails" nocol.md 1 "FAIL: has a Relationships table with upstream, downstream, pattern, reason and contract columns"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-pattern-rationale: no argument exits 2" || _fail "validate-pattern-rationale: no argument exits 2" "exit $code"

smoke_test_summary
