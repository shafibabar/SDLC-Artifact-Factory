#!/bin/bash
# Tests skills/integration-design/scripts/validate-integration-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/integration-design/scripts/validate-integration-design.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> [substring] -- <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-integration-design: $label"
  else
    _fail "validate-integration-design: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: integration-design
product: sailtrack
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-01
summary: Sailtrack's integrations.
traces-to: [design/architecture/container-diagram.md]
---

# Integration Design for Sailtrack

**Readers:** enterprise-architect, backend-engineer
**Question it answers:** how does each integration talk and fail?

- **Profile:** standard

## Integration Inventory

| From | To | Shape | Consistency | Protocol | Contract strictness | Contract test | Resilience |
|---|---|---|---|---|---|---|---|
| Regattas | Tide API | request/response | eventual | HTTPS/JSON | loose (tolerant reader) | Consumer-Driven Contract | timeout, retry (read), breaker, bulkhead, fallback |
| Regattas | `race-finished` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | Transactional Outbox |
| Rankings | `race-finished` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | idempotent consumer, retry, DLQ |

## Synchronous Integrations

### Regattas → Tide API

- **Why sync:** start times need the tide now
- **Timeout:** 1 s
- **Retry:** 2 retries with jitter (a read)
- **Circuit breaker:** 50% of 20 in 30 s
- **Bulkhead:** own client
- **Fallback:** last tide table, marked stale

## Asynchronous Integrations

| Topic | Publisher (mechanism) | Consumers (group) | Idempotency | Retry and DLQ |
|---|---|---|---|---|
| `race-finished` | Regattas (Transactional Outbox) | Rankings (`rankings`) | event id | 1 s, 5 s; then `rankings.dlq` |

## Cross-Context Reads

| Reader | Data owned by | Option | Why not the others |
|---|---|---|---|
| Rankings | Regattas | event replication | read often, lag is fine |

## Open Questions

- none
EOF

expect "a complete design passes" 0 "" good.md

sed 's/| Regattas | Tide API | request\/response | eventual |/| Regattas | Tide API | request\/response | |/' good.md > nocons.md
expect "a row without consistency fails" 1 "consistency is atomic or eventual" nocons.md

sed 's/| HTTPS\/JSON | loose (tolerant reader) | Consumer-Driven Contract |/| HTTPS\/JSON | | Consumer-Driven Contract |/' good.md > nostrict.md
expect "a row without contract strictness fails" 1 "contract strictness is strict or loose" nostrict.md

sed 's/| loose (tolerant reader) | Consumer-Driven Contract |/| loose (tolerant reader) | CDC test |/' good.md > cdc.md
expect "a contract test written as CDC fails" 1 "doesn't abbreviate Consumer-Driven Contract as CDC" cdc.md

sed 's/| timeout, retry (read), breaker, bulkhead, fallback |/| retry, breaker, bulkhead, fallback |/' good.md > notimeout.md
expect "a sync call without a timeout fails" 1 "has a timeout" notimeout.md

sed 's/| timeout, retry (read), breaker, bulkhead, fallback |/| timeout, retry 3x, breaker, bulkhead, fallback |/' good.md > blindretry.md
expect "a retry that is neither idempotent nor keyed fails" 1 "retries only idempotent or keyed" blindretry.md

sed 's/| timeout, retry (read), breaker, bulkhead, fallback |/| timeout, retry (read), fallback |/' good.md > nobreaker.md
expect "a standard sync call without a breaker fails" 1 "has a circuit breaker" nobreaker.md

sed 's/| timeout, retry (read), breaker, bulkhead, fallback |/| timeout, retry (read); risk-accepted: one low-traffic partner |/' good.md > accepted.md
expect "a risk-accepted breaker with a reason passes" 0 "" accepted.md

sed 's/| timeout, retry (read), breaker, bulkhead, fallback |/| timeout, retry (read), risk-accepted |/' good.md > noreason.md
expect "a risk-accepted choice without a reason fails" 1 "gives its reason" noreason.md

sed 's/| idempotent consumer, retry, DLQ |/| consumer |/' good.md > nomech.md
expect "an async row without a mechanism fails" 1 "names its mechanism" nomech.md

sed 's/| Regattas | Tide API | request\/response | eventual | HTTPS\/JSON |/| Regattas | Tide API | request\/response | eventual | Kafka protocol |/' good.md > reqreply.md
expect "request/reply over the broker fails" 1 "no request/reply over the broker" reqreply.md

sed 's/| Rankings | Regattas | event replication |/| Rankings | Regattas | shared database |/' good.md > shared.md
expect "a shared database read fails" 1 "option is API composition, event replication or Change Data Capture" shared.md

sed '/^- \*\*Timeout:\*\* 1 s$/d' good.md > nodetail.md
expect "a sync detail block without a timeout fails" 1 "timeout stated" nodetail.md

sed 's/^- \*\*Retry:\*\* 2 retries with jitter (a read)$/- **Retry:** 3 retries/' good.md > blinddetail.md
expect "a sync detail retry that isn't idempotent or keyed fails" 1 "retry says idempotent" blinddetail.md

sed 's/^## Cross-Context Reads$/## Coordination\n\n- **Race weekend:** choreographed; eventual\n\n## Cross-Context Reads/' good.md > coord.md
expect "a coordinated flow missing the three axes fails" 1 "states communication, consistency and coordination" coord.md

sed 's/^## Cross-Context Reads$/## Coordination\n\n- **Race weekend:** communication: async · consistency: eventual · coordination: choreographed (anthology saga)\n\n## Cross-Context Reads/' good.md > coordok.md
expect "a coordinated flow on three axes passes" 0 "" coordok.md

sed 's/^- \*\*Profile:\*\* standard$/- **Profile:** lean/' good.md > leanlong.md
expect "a lean artifact with extra sections fails (keep it short)" 1 "lean artifact is short" leanlong.md

awk '/^## Synchronous Integrations$/{skip=1} /^## Open Questions$/{skip=0} !skip' leanlong.md > leanshort.md
expect "a short lean artifact (inventory and open questions) passes" 0 "" leanshort.md

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" 1 "FAIL: frontmatter has" notrace.md

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-integration-design: no argument exits 2" || _fail "validate-integration-design: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-integration-design: a missing file exits 2" || _fail "validate-integration-design: a missing file exits 2" "exit $code"

smoke_test_summary
