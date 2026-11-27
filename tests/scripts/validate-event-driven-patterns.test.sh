#!/bin/bash
# Tests skills/event-driven-patterns/scripts/validate-event-driven-patterns.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/event-driven-patterns/scripts/validate-event-driven-patterns.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> [substring] -- <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-event-driven-patterns: $label"
  else
    _fail "validate-event-driven-patterns: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
# Integration Design for Sailtrack

## Event-Driven Pattern Decisions

- **Profile:** standard
- **Broker:** Redpanda

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| RaceFinished from Results to Rankings | async | eventual | choreographed | two services, independent reaction |
| Register a boat | async | eventual | orchestrated | branching and compensation across 4 services; designed in workflow-orchestration |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| Results service | Transactional Outbox | emits with its own write |
| Legacy timing system | Change Data Capture | legacy code that cannot publish |

### Topics and Ordering

| Topic | Partition key | Ordering guaranteed | Consumer groups | Retention |
|---|---|---|---|---|
| results.finished | boat id | per boat within a partition | rankings | 7 days |

### Delivery and Idempotency

| Consumer | Dedup (key and store) | Retry and Backoff | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Rankings | event id in a dedup table with the effect | transient only, 5 attempts, jitter | results.finished.dlq | depth above zero |

### Open Questions

- Largest fleet size.

## Next Section

text
EOF

expect "a complete section passes" 0 "" good.md

printf '# Doc\n\n## Other\n' > nosection.md
expect "a file without the section fails" 1 "section is present" nosection.md

sed 's/| async | eventual | choreographed | two services/| async | atomic | choreographed | two services/' good.md > atomicchor.md
expect "atomic and choreographed fails" 1 "never atomic and choreographed" atomicchor.md

sed 's/branching and compensation across 4 services; designed in workflow-orchestration/branching and compensation across 4 services/' good.md > noorch.md
expect "an orchestrated flow without the pointer fails" 1 "points to workflow-orchestration" noorch.md

sed 's/| async | eventual | choreographed |/| async | eventual | |/' good.md > nocoord.md
expect "a flow without coordination fails" 1 "coordination is choreographed or orchestrated" nocoord.md

sed 's/| legacy code that cannot publish |/| we like it |/' good.md > cdcwhy.md
expect "Change Data Capture without a reason fails" 1 "says why the source cannot publish" cdcwhy.md

sed 's/| Transactional Outbox | emits with its own write |/| we publish after commit | emits with its own write |/' good.md > nomech.md
expect "a publisher without a known mechanism fails" 1 "mechanism is Outbox" nomech.md

sed 's/| boat id | per boat/| round-robin | per boat/' good.md > rr.md
expect "a round-robin partition key fails" 1 "not random or round-robin" rr.md

sed 's/| per boat within a partition |/| |/' good.md > noorder.md
expect "a topic without a stated ordering fails" 1 "ordering guarantee is stated" noorder.md

sed 's/| transient only, 5 attempts, jitter |/| retry until it works |/' good.md > infinite.md
expect "unlimited retry fails" 1 "not unlimited" infinite.md

sed 's/| results.finished.dlq |/| |/' good.md > nodlq.md
expect "a consumer without a Dead Letter Queue fails" 1 "Dead Letter Queue is stated" nodlq.md

sed 's/| results.finished.dlq |/| risk-accepted: replay from the log is cheap |/' good.md > dlqaccepted.md
expect "a risk-accepted Dead Letter Queue passes" 0 "" dlqaccepted.md

sed 's/| event id in a dedup table with the effect |/| none |/' good.md > nodedup.md
expect "no dedup without risk-accepted fails" 1 "dedup is not 'none'" nodedup.md

sed 's/^- Largest fleet size.$//' good.md > noq.md
expect "no open question fails" 1 "open questions has at least one bullet" noq.md

sed 's/| Results service | Transactional Outbox | emits with its own write |/| Results service | Transactional Outbox | Consumer-Driven Contract (CDC) test |/' good.md > cdcabbr.md
expect "CDC used for Consumer-Driven Contract fails" 1 "not used for Consumer-Driven Contract" cdcabbr.md

# lean without a broker: short form passes; topics must be absent
cat > lean.md <<'EOF'
## Event-Driven Pattern Decisions

- **Profile:** lean
- **Broker:** none: in-process events inside one deployable

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| A to B | async | eventual | choreographed | two modules in one deployable |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| Module A | in-process publisher | one deployable |

### Open Questions

- When B becomes its own service.
EOF
expect "a short lean section with no broker passes" 0 "" lean.md

sed_multiline 's/^### Open Questions/### Topics and Ordering\n\n| Topic | Partition key | Ordering guaranteed | Consumer groups | Retention |\n|---|---|---|---|---|\n| t | k | o | g | r |\n\n### Open Questions/' lean.md > leantopics.md
expect "lean with no broker but a topics table fails" 1 "no topics or delivery tables" leantopics.md

sed 's/^- \*\*Broker:\*\*.*$/- **Broker:** [broker]/' good.md > nobroker.md
expect "an unfilled broker line fails" 1 "broker line is filled" nobroker.md

expect "a missing file is a usage error" 2 "" nope.md

smoke_test_summary
