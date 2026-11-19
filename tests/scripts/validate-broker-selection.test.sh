#!/bin/bash
# Tests skills/message-broker-selection/scripts/validate-broker-selection.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/message-broker-selection/scripts/validate-broker-selection.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-broker-selection: $label"
  else
    _fail "validate-broker-selection: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <name> <old> <new>: copy good.md with one replacement
  python3 - "$1" "$2" "$3" <<'PY'
import sys
name, old, new = sys.argv[1:4]
t = open("good.md").read()
assert old in t, "fixture missing: " + old
open(name, "w").write(t.replace(old, new, 1))
PY
}

cat > good.md <<'EOF'
---
name: broker-selection-rationale
product: stampbook
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: Collection events run on a log because a new consumer must replay history.
traces-to: [design/architecture/integration-design.md]
---

# Broker Selection Rationale for Stampbook

- **Profile:** standard
- **Broker needed:** yes

## Need for a Broker

Services are separate and a Reporting consumer needs history.

## Workloads

| Workload | Replay needed | Order needed | Routing or fan-out | Broker model | Why |
|---|---|---|---|---|---|
| Collection events | yes: Reporting joins later | per collection | two consumers | log | replay first |
| Label print jobs | no: done once handled | none | one pool | queue | fair dispatch of uneven jobs |

## Decision

- **Broker:** Redpanda for events; RabbitMQ for print jobs
- **Why this one:** events need replay; the second broker handles a workload that answers the replay question differently and its operating cost is accepted
- **Hosting and owner:** self-run; platform-engineer on call
- **Retention:** 30 days for a Reporting rebuild
- **ADR:** ADR-0002

## Delivery

| Broker | Acknowledgement | Retry | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Redpanda | offset committed after the work is durable | transient only, retry topic with backoff | dead-letter topic, re-driven by owner | lag; dead-letter depth |
| RabbitMQ | acknowledged after the file is stored | transient only, delay queue | dead-letter queue, re-driven by owner | queue depth |

## Revisit When

- Print jobs need replay.

## Open Questions

- Whether print jobs need a priority lane; owner: product owner.
EOF

cat > nobroker.md <<'EOF'
---
name: broker-selection-rationale
product: plotline
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: No broker: in-process events inside one deployable.
traces-to: [design/architecture/container-diagram.md]
---

# Broker Selection Rationale for Plotline

- **Profile:** lean
- **Broker needed:** no

## Need for a Broker

Every flow stays inside one deployable, so events are published in-process. This would change if a module becomes its own deployable.

## Revisit When

- A module is split out.

## Open Questions

- none: nothing is open yet.
EOF
sed -i 's/^- none: nothing is open yet\./- None: no questions yet./' nobroker.md

expect "a complete document passes" 0 "0 check(s) failed" good.md
expect "a no-broker document passes" 0 "0 check(s) failed" nobroker.md
expect "missing file is a usage error" 2 "" nosuch.md
out="$("$VALIDATE" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -qF "Usage"; then
  _pass "validate-broker-selection: no arguments is a usage error"
else
  _fail "validate-broker-selection: no arguments is a usage error" "exit $code"
fi

mutate bad-name.md "name: broker-selection-rationale" "name: other"
expect "wrong frontmatter name fails" 1 "frontmatter name is broker-selection-rationale" bad-name.md

mutate bad-needed.md "**Broker needed:** yes" "**Broker needed:** maybe"
expect "broker needed must be yes or no" 1 "'Broker needed' is yes or no" bad-needed.md

mutate replay-queue.md "| yes: Reporting joins later | per collection | two consumers | log |" "| yes: Reporting joins later | per collection | two consumers | queue |"
expect "a replay-needing workload on a queue fails" 1 "not on a queue" replay-queue.md

mutate no-replay.md "| yes: Reporting joins later |" "| |"
expect "workload without a replay answer fails" 1 "a replay answer (yes or no) is given" no-replay.md

mutate bad-model.md "| two consumers | log | replay first |" "| two consumers | stream | replay first |"
expect "model must be log or queue" 1 "model is log or queue" bad-model.md

mutate cc-log.md "| log | replay first |" "| log | competing consumers scale it |"
expect "Competing Consumers on a log fails" 1 "Competing Consumers is not used for a log" cc-log.md

mutate no-adr.md "- **ADR:** ADR-0002" "- **ADR:** "
expect "decision without an ADR line fails" 1 "decision: 'adr' is filled" no-adr.md

mutate no-reason.md "the second broker handles a workload that answers the replay question differently and its operating cost is accepted" "it is popular"
expect "two models without a second-broker reason fails" 1 "second broker's reason and cost" no-reason.md

mutate autoack.md "acknowledged after the file is stored" "auto-ack so there is no redelivery"
expect "auto-acknowledge fails" 1 "no auto-acknowledge" autoack.md

mutate unlimited.md "transient only, delay queue" "retry every failure forever"
expect "unlimited retry fails" 1 "retry is not unlimited" unlimited.md

mutate no-dlq.md "dead-letter queue, re-driven by owner" "?"
expect "missing Dead Letter Queue fails" 1 "Dead Letter Queue is stated" no-dlq.md

mutate no-bullet.md "- Print jobs need replay." "nothing"
expect "no revisit trigger fails" 1 "revisit triggers have at least one bullet" no-bullet.md

mutate cdc.md "- **Profile:** standard" "- **Profile:** standard
Consumer-Driven Contract tests (CDC) cover it."
expect "CDC used for Consumer-Driven Contract fails" 1 "'CDC' is not used" cdc.md

mutate lean-broker.md "- **Profile:** standard" "- **Profile:** lean"
expect "lean with a broker warns but passes" 0 "WARN: lean profile" lean-broker.md

mutate code.md "## Revisit When" '```
code
```

## Revisit When'
expect "a code block warns" 0 "WARN: a code block" code.md

python3 - <<'PY'
t = open("nobroker.md").read()
open("nobroker-rows.md", "w").write(t.replace("## Revisit When", """## Workloads

| Workload | Replay needed | Order needed | Routing or fan-out | Broker model | Why |
|---|---|---|---|---|---|
| events | yes | none | none | log | x |

## Revisit When"""))
open("nobroker-noinproc.md", "w").write(t.replace("in-process", "inline"))
PY
expect "no broker but workload rows fails" 1 "no workload rows" nobroker-rows.md
expect "no broker without in-process events fails" 1 "names in-process events" nobroker-noinproc.md

smoke_test_summary
