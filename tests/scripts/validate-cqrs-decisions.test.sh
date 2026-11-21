#!/bin/bash
# Tests skills/cqrs-pattern/scripts/validate-cqrs-decisions.sh — a skill-owned
# script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/cqrs-pattern/scripts/validate-cqrs-decisions.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-cqrs-decisions: $1"
  else
    _fail "validate-cqrs-decisions: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: cqrs-design
product: tidelog
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-02-09
summary: Moorings uses a Simple Read Model; Tides projects a harbour-wide board on a load trigger.
profile: standard
traces-to: [design/moorings/aggregates.md, ideate/nfr-specification.md]
---

# CQRS Decisions: Tidelog

## Contexts

| Bounded Context | Read side | Trigger | Staleness accepted |
|---|---|---|---|
| Moorings | simple read model | none — rung 1 | immediate |
| Tides | projections | harbour board load | 30 seconds |

## Context: Moorings

| Field | Value |
|---|---|
| **Read side** | simple read model |
| **Business-logic pattern** | Domain Model |
| **Event sourced** | no |
| **Trigger** | none — a Simple Read Model serves every query |
| **Staleness accepted** | immediate |
| **Read-your-writes** | immediate (same tables) |
| **Replicas or regions** | one copy |
| **Revisit when** | a second screen needs a different shape of the mooring list |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| Berths free tonight | simple read model | one join over two tables |

## Context: Tides

| Field | Value |
|---|---|
| **Read side** | projections |
| **Business-logic pattern** | Domain Model |
| **Event sourced** | no |
| **Trigger** | harbour board: NFR says 40 reads per second against 1 write per minute, and each read aggregates 300 berth readings; computing it per request slows recording |
| **Staleness accepted** | 30 seconds — skippers plan by the hour |
| **Read-your-writes** | the Command returns the version; the harbour master's view shows pending until applied |
| **Replicas or regions** | one copy |
| **Revisit when** | readings per minute exceed what one projector keeps up with |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| Harbour board | projection: HarbourBoard | the trigger |

## Cross-service queries

| Query | Services | Approach | Trigger | Owner of the view |
|---|---|---|---|---|
| Skipper's booking with tide window | Moorings, Tides | API Composition | none — composition | — |
EOF
expect "a complete record passes and counts contexts" good.md 0 "INFO: 2 context(s), 1 projected"

sed 's/^| \*\*Trigger\*\* | harbour board: .*$/| **Trigger** | none |/' good.md > notrig.md
expect "projections with no trigger fail" notrig.md 1 "FAIL: Tides: projections name a trigger"

sed 's/^| \*\*Trigger\*\* | harbour board: .*$/| **Trigger** | we might need to scale the board, and it is best practice |/' good.md > wish.md
expect "a wish as a trigger fails" wish.md 1 "FAIL: Tides: the trigger is evidence, not a wish"

sed 's/^| \*\*Staleness accepted\*\* | 30 seconds — skippers plan by the hour |$/| **Staleness accepted** | immediate |/' good.md > stale.md
expect "a projected context claiming immediate consistency fails" stale.md 1 "projected views accept some staleness"

sed '0,/^| \*\*Event sourced\*\* | no |$/s//| **Event sourced** | yes — Mooring; projections are required |/' good.md > es.md
expect "an event-sourced context on a Simple Read Model fails" es.md 1 "FAIL: Moorings: an event-sourced context is on projections"

sed 's/^| Berths free tonight | simple read model | one join over two tables |$/| Berths free tonight | projection: BerthBoard | faster |/' good.md > qproj.md
expect "a projection query in a rung-1 context fails" qproj.md 1 "is served by a projection, but the context is not on projections"

sed 's/^| \*\*Read side\*\* | simple read model |$/| **Read side** | full CQRS |/' good.md > side.md
expect "an unknown read side fails" side.md 1 "read side is 'simple read model' or 'projections'"

sed '0,/^| \*\*Revisit when\*\* | a second screen.*$/s//| **Revisit when** | |/' good.md > norev.md
expect "a missing revisit-when fails" norev.md 1 "FAIL: Moorings: 'revisit when' is filled in"

sed 's/^| Skipper.s booking with tide window | Moorings, Tides | API Composition | none — composition | — |$/| Skipper booking | Moorings, Tides | CQRS view | | |/' good.md > xview.md
expect "a cross-service CQRS view with no trigger or owner fails" xview.md 1 "a CQRS view names a trigger"

sed 's/^| Skipper.s booking with tide window | Moorings, Tides | API Composition | none — composition | — |$/| Skipper booking | Moorings, Tides | shared database | — | — |/' good.md > shared.md
expect "a shared-database approach fails" shared.md 1 "approach is API Composition or CQRS view"

sed 's/^| Tides | projections | harbour board load | 30 seconds |$/| Tides | projections | harbour board load | 30 seconds |\n| Weather | simple read model | none | immediate |/' good.md > orphan.md
expect "a summary row with no context block fails" orphan.md 1 "missing: Weather"

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

{ cat good.md; printf '\n```sql\nCREATE TABLE harbour_board (id int);\n```\n'; } > code.md
expect "code in the record fails (D047-10)" code.md 1 "FAIL: no code or DDL"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-cqrs-decisions: no argument exits 2" || _fail "validate-cqrs-decisions: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-cqrs-decisions: a missing file exits 2" || _fail "validate-cqrs-decisions: a missing file exits 2" "exit $code"

smoke_test_summary
