#!/bin/bash
# Tests skills/aggregate-design/scripts/validate-aggregate-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/aggregate-design/scripts/validate-aggregate-design.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-aggregate-design: $1"
  else
    _fail "validate-aggregate-design: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: aggregate-design
product: kilnshare
bounded-context: Firing
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-02
summary: Firing has one Aggregate, Kiln, guarding shelf capacity per firing.
profile: standard
traces-to: [design/firing/ubiquitous-language.md, design/context-map.md]
---

# Aggregate Design: Firing

## Aggregate: Kiln

| Field | Value |
|---|---|
| **Root** | Kiln: one kiln's scheduled firings and their loads |
| **Pattern** | Domain Model — shelf space per firing must never be over-allocated |
| **Identity** | client-generated |
| **Concurrency** | optimistic |
| **Event sourcing** | not used — no temporal query, retroactive projection or audit-as-record need |
| **Contention** | low — a few members book per day |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| Loads booked into a firing never exceed its shelf space. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| The member's booking count equals their loads. | no | yes | yes | query |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| Member | yes | no | separate | by ID |

## Use case: Update studio notice

| Field | Value |
|---|---|
| **Pattern** | Transaction Script — one text field, no rule across records |
| **Records touched** | notice |
| **Rules** | none |
EOF
expect "a complete design passes and counts blocks" good.md 0 "INFO: 1 Aggregate(s), 1 use case(s)"

sed 's/| Loads booked into a firing never exceed its shelf space. | yes | no | no |/| Loads booked into a firing never exceed its shelf space. | yes | yes | no |/' good.md > noinv.md
expect "a 'True Invariant' that is fixable later fails" noinv.md 1 "FAIL: Kiln: 'Loads booked into a firing never exceed its shelf space.' answers yes / no / no"

sed '/| Loads booked into a firing/d' good.md > zeroinv.md
expect "an Aggregate with no True Invariant fails" zeroinv.md 1 "FAIL: Kiln: at least one True Invariant"

sed 's/| Member | yes | no | separate | by ID |/| Member | yes | no | merged | contains the Member object |/' good.md > objref.md
expect "a relationship held by object fails" objref.md 1 "FAIL: Kiln → Member: referenced by ID, not by object"

sed 's/| Member | yes | no | separate | by ID |/| Member | | no | separate | by ID |/' good.md > nohasa.md
expect "a relationship without its has-a answer fails" nohasa.md 1 "FAIL: Kiln → Member: has-a and must-be-atomic both answered"

sed 's/| \*\*Pattern\*\* | Domain Model — shelf space per firing must never be over-allocated |/| **Pattern** | Event-Sourced Domain Model — it is Core |/; s/| \*\*Event sourcing\*\* | not used — no temporal query, retroactive projection or audit-as-record need |/| **Event sourcing** | used — the subdomain is Core |/' good.md > escore.md
expect "event sourcing justified by Core alone fails" escore.md 1 "FAIL: Kiln: event sourcing names the need it meets"

sed 's/| \*\*Event sourcing\*\* | not used — no temporal query, retroactive projection or audit-as-record need |/| **Event sourcing** | used — temporal query: state as of each firing |/' good.md > esmismatch.md
expect "event sourcing 'used' on a current-state Aggregate fails" esmismatch.md 1 "FAIL: Kiln: event-sourcing field agrees with the pattern"

sed 's/| \*\*Concurrency\*\* | optimistic |/| **Concurrency** | pessimistic |/' good.md > pess.md
expect "pessimistic concurrency without its condition fails" pess.md 1 "FAIL: Kiln: non-default concurrency names its condition"

sed 's/| \*\*Pattern\*\* | Transaction Script — one text field, no rule across records |/| **Pattern** | Domain Model — to be safe |/' good.md > casepat.md
expect "a use case block with a Domain Model pattern fails" casepat.md 1 "FAIL: Update studio notice: pattern is Transaction Script or Active Record"

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

{ cat good.md; printf '\n```go\ntype Kiln struct{}\n```\n'; } > code.md
expect "code in the design fails (D047-10)" code.md 1 "FAIL: no code in the design"

sed 's/^name: aggregate-design$/name: domain-model/; /^bounded-context:/d' good.md > lean.md
expect "a lean document without Domain Events, Commands and Read Models fails" lean.md 1 "FAIL: lean document has a '## Domain Events' section"

{ sed 's/| \*\*Root\*\* |/| **Context** | Firing |\n| **Root** |/; s/| \*\*Records touched\*\* |/| **Context** | Studio |\n| **Records touched** |/' lean.md
  printf '\n## Domain Events\n\n| Context | Event (past tense) | Raised by | Carries | Who reacts |\n|---|---|---|---|---|\n| Firing | LoadBookedIntoFiring | BookLoad | load | schedule view |\n| Firing | FiringSchedule | ScheduleFiring | firing | members |\n'
  printf '\n## Commands\n\n| Context | Command | Guard | Handled by | Idempotency |\n|---|---|---|---|---|\n| Firing | BookLoad | space left | Kiln | request id |\n'
  printf '\n## Read Models\n\n| Context | Read Model | Answers | Built from | Staleness accepted |\n|---|---|---|---|---|\n| Firing | Schedule | what fires when | events | seconds |\n'; } > leanfull.md
expect "a complete lean document passes" leanfull.md 0 "INFO: 1 Aggregate(s), 1 use case(s)"
expect "a mid-name past-tense verb is not flagged, a missing one warns" leanfull.md 0 "WARN: event 'FiringSchedule' may not be past tense"
if "$VALIDATE" leanfull.md 2>&1 | grep -q "LoadBookedIntoFiring"; then
  _fail "validate-aggregate-design: 'LoadBookedIntoFiring' is read as past tense" "it was flagged"
else
  _pass "validate-aggregate-design: 'LoadBookedIntoFiring' is read as past tense"
fi

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-aggregate-design: no argument exits 2" || _fail "validate-aggregate-design: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-aggregate-design: a missing file exits 2" || _fail "validate-aggregate-design: a missing file exits 2" "exit $code"

smoke_test_summary
