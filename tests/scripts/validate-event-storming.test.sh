#!/bin/bash
# Tests skills/event-storming-facilitation/scripts/validate-event-storming.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/event-storming-facilitation/scripts/validate-event-storming.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-event-storming: $1"
  else
    _fail "validate-event-storming: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

FM='---
name: event-storming-big-picture
product: kettlewise
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-01-05
summary: Kettlewise Big Picture; two candidates.
profile: lean
mode: agent-run
traces-to: [strategy/vision.md, ideate/job-stories.md]
---'

cat > bp-good.md <<EOF
$FM

## Timeline

| # | Domain Event | Actor or system | Swimlane | Source |
|---|---|---|---|---|
| 1 | **SubscriptionStarted** | Customer | Sales | ideate/job-stories.md J1 |
| 2 | BoxShipped | Warehouse | Fulfilment | *assumed* |

## Pivotal Events

| Event | Why it marks a change of phase |
|---|---|
| SubscriptionStarted | Sales hands over to fulfilment |

## Bounded Context Candidates (hints, not decisions)

| Candidate | Spans events | Evidence |
|---|---|---|
| Sales | 1 | Actor customer; "box" = a plan |
| Fulfilment | 2 | Actor warehouse; "box" = a parcel |

## Hotspots (ranked)

| Rank | ID | Hotspot | Kind | Goes to | Question for the product owner | Assumed meanwhile |
|---|---|---|---|---|---|---|
| 1 | H1 | Skipped weeks | Rule | Product owner | Can a customer skip a week? | No |
EOF
expect "a complete agent-run Big Picture passes and counts assumed cards" bp-good.md 0 "1 card(s) marked *assumed*"

sed 's/| ideate\/job-stories.md J1 |/| |/' bp-good.md > bp-nosource.md
expect "a card with no source fails" bp-nosource.md 1 "FAIL: every card in a table with a Source column has a source"

sed 's/| Actor customer; "box" = a plan |/| |/' bp-good.md > bp-noevidence.md
expect "a boundary candidate with no evidence fails" bp-noevidence.md 1 "FAIL: Big Picture records Bounded Context candidates with evidence"

awk '/^## Bounded Context Candidates/{skip=1} /^## Hotspots/{skip=0} !skip' bp-good.md > bp-nobc.md
expect "a lean Big Picture with no boundary candidates fails" bp-nobc.md 1 "FAIL: Big Picture records Bounded Context candidates"

{ cat bp-good.md; printf '\n## Aggregates\n\n| Aggregate |\n|---|\n| Box |\n'; } > bp-agg.md
expect "aggregates in a Big Picture fail" bp-agg.md 1 "FAIL: Big Picture names no aggregates"

sed 's/| No |$/| Resolved: no skipping |/' bp-good.md > bp-resolved.md
expect "a hotspot marked resolved fails" bp-resolved.md 1 "FAIL: no hotspot is marked resolved"

{ cat bp-good.md; printf '\n## Next\n\nRules per area: Sales must hold the invariant one plan per customer.\n'; } > bp-inv.md
expect "invariants in a Big Picture warn (aggregates in disguise)" bp-inv.md 0 "WARN: a Big Picture mentions invariants"

sed 's/BoxShipped/OrderRowInserted/' bp-good.md > bp-tech.md
expect "a technical event warns but does not fail" bp-tech.md 0 "WARN: 'OrderRowInserted' looks like a technical event"

sed 's/^traces-to: .*/traces-to: []/' bp-good.md > bp-notraces.md
expect "an agent-run wall with no traces-to fails" bp-notraces.md 1 "FAIL: agent-run transcript lists its input artifacts"

cat > design.md <<'EOF'
---
name: event-storming-design-level
product: kettlewise
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-01-09
summary: Kettlewise Software Design.
profile: standard
mode: human session on 2026-01-09 with ops and support
---

## Aggregates (consistency units)

| Aggregate | Commands handled | Events emitted | Invariant that must hold at every instant | Source |
|---|---|---|---|---|
| Subscription | Start, Pause | SubscriptionStarted | One active plan per customer | session 2026-01-09 |

## Bounded Context Candidates

| Candidate | Aggregates inside | Language change that justifies the boundary | Big Picture hint it confirms |
|---|---|---|---|
| Sales | Subscription | "box" means a plan | Pivotal SubscriptionStarted |

## Hotspots

| ID | Hotspot | Kind | Goes to | Question for the product owner | Assumed meanwhile |
|---|---|---|---|---|---|
EOF
expect "a complete Software Design transcript passes" design.md 0
sed 's/| One active plan per customer |/| |/' design.md > design-noinv.md
expect "an aggregate with no invariant fails" design-noinv.md 1 "FAIL: every aggregate states the invariant"

cat > process.md <<'EOF'
---
name: event-storming-process-signup
product: kettlewise
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-01-07
summary: Kettlewise signup process.
profile: standard
mode: agent-run
traces-to: [design/event-storming/big-picture.md]
---

## Paths

| Path | Read Model | Actor or Policy | Command | System | Domain Event | Source |
|---|---|---|---|---|---|---|
| Happy | Plans | Customer | StartSubscription | Our software | SubscriptionStarted | ideate/job-stories.md J1 |

**Stable ends:** SubscriptionStarted.

## Policies

| ID | Whenever (event) | Then (command) | Automatic or by a person |
|---|---|---|---|
| P1 | SubscriptionStarted | ScheduleFirstBox | Automatic |

## Breaks in the Chain (hotspots)

| ID | Where the chain breaks | Question for the product owner | Assumed meanwhile |
|---|---|---|---|
EOF
expect "a complete Process Modelling transcript passes" process.md 0
sed 's/| P1 | SubscriptionStarted | ScheduleFirstBox |/| P1 | SubscriptionStarted | |/' process.md > process-nothen.md
expect "a policy with no 'then' fails" process-nothen.md 1 "FAIL: every policy reads whenever"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-event-storming: no argument exits 2" || _fail "validate-event-storming: no argument exits 2" "exit $code"

smoke_test_summary
