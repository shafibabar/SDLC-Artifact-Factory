#!/bin/bash
# Tests skills/workflow-orchestration/scripts/validate-workflow-orchestration.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/workflow-orchestration/scripts/validate-workflow-orchestration.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -F -- "$sub" >/dev/null; }; then
    _pass "validate-workflow-orchestration: $label"
  else
    _fail "validate-workflow-orchestration: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

# mutate <name> <python replace expr: old> <new>: copy good.md with one replacement
mutate() {
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
name: workflow-orchestration-design
product: tablefare
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: Reservation flow is orchestrated, with the deposit capture as its one pivot.
traces-to: [design/architecture/integration-design.md]
---

# Workflow Orchestration Design for Tablefare

- **Profile:** standard

## Orchestration Decision

| Flow | Trigger that fired | Why not choreography | Coordinator |
|---|---|---|---|
| Reserve a table | long-running (host confirms within a day) and compensation across 4 services | no owner for the suspended flow | hand-rolled in the Reservations deployment |

## Saga: Reserve a table

**Pivot:** step 3, capturing the deposit
**Coordinator:** a state record per reservation in the Reservations deployment
**State persistence:** state and next command written in one transaction through the Transactional Outbox
**Business logic in the coordinator:** none: it sends commands and records replies

### Steps

| # | Step (command) | Owner | Class | Compensation | Captured on the way forward | Lock set or cleared |
|---|---|---|---|---|---|---|
| 1 | HoldTable | Reservations | compensatable | ReleaseTable | hold id | sets table `held` |
| 2 | RequestHostConfirmation | Hosts | compensatable | WithdrawRequest | request id | none |
| 3 | CaptureDeposit | Payments | pivot | none | none | none |
| 4 | ConfirmTable | Reservations | retriable | none | none | clears table to `reserved` |

### State Machine

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| Holding table | HoldTable | Awaiting host | Compensated |
| Awaiting host | RequestHostConfirmation | Capturing deposit | Releasing table |
| Capturing deposit | CaptureDeposit | Confirming table | Withdrawing request |
| Confirming table | ConfirmTable | Completed | retry with backoff, then Needs repair |

### Timeouts

| Wait | Timeout | When it expires |
|---|---|---|
| Host confirmation | 24 hours | compensate and tell the guest |

### Isolation

| Record exposed | Anomaly possible | Countermeasure | Cleared by, and how a stale one is released |
|---|---|---|---|
| Table | dirty read | semantic lock: table state `held` | cleared by ConfirmTable or ReleaseTable; a hold older than 36 hours is released by a sweeper |

## Open Questions

- Whether guests see "held"; owner: product owner.
EOF

: > empty.md

expect "a complete document passes" 0 "0 check(s) failed" good.md
expect "missing file is a usage error" 2 "" nosuch.md
out="$("$VALIDATE" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -F "Usage" >/dev/null; then
  _pass "validate-workflow-orchestration: no arguments is a usage error"
else
  _fail "validate-workflow-orchestration: no arguments is a usage error" "exit $code"
fi

mutate no-fm.md "name: workflow-orchestration-design" "name: something-else"
expect "wrong frontmatter name fails" 1 "frontmatter name is workflow-orchestration-design" no-fm.md

mutate no-trigger.md "long-running (host confirms within a day) and compensation across 4 services" "it felt complex"
expect "decision without a Richardson trigger fails" 1 "a Richardson trigger is named" no-trigger.md

mutate two-pivots.md "| 4 | ConfirmTable | Reservations | retriable |" "| 4 | ConfirmTable | Reservations | pivot |"
expect "two pivots fail" 1 "exactly one pivot" two-pivots.md

mutate no-pivot.md "| 3 | CaptureDeposit | Payments | pivot |" "| 3 | CaptureDeposit | Payments | retriable |"
expect "no pivot fails" 1 "exactly one pivot" no-pivot.md

mutate no-comp.md "| compensatable | ReleaseTable |" "| compensatable | none |"
expect "compensatable step without compensation fails" 1 "a compensation is written" no-comp.md

mutate lookup.md "| hold id |" "| look up current state |"
expect "compensation by lookup fails" 1 "captured data is named" lookup.md

mutate comp-after.md "| 4 | ConfirmTable | Reservations | retriable | none |" "| 4 | ConfirmTable | Reservations | retriable | UndoConfirm |"
expect "compensation after the pivot fails" 1 "no compensation after the pivot commits" comp-after.md

mutate retri-before.md "| 1 | HoldTable | Reservations | compensatable |" "| 1 | HoldTable | Reservations | retriable |"
expect "retriable before the pivot fails" 1 "retriable steps all come after the pivot" retri-before.md

mutate comp-late.md "| 4 | ConfirmTable | Reservations | retriable | none | none |" "| 4 | ConfirmTable | Reservations | compensatable | UndoConfirm | confirmation id |"
expect "compensatable after the pivot fails" 1 "compensatable steps all come before the pivot" comp-late.md

mutate memory.md "written in one transaction through the Transactional Outbox" "kept in memory"
expect "in-memory coordinator fails" 1 "persistence uses the Outbox in one transaction" memory.md

mutate logic.md "**Business logic in the coordinator:** none: it sends commands and records replies" "**Business logic in the coordinator:** it checks the deposit amount"
expect "business logic in the coordinator fails" 1 "no business logic in the coordinator" logic.md

mutate no-expiry.md "| 24 hours | compensate and tell the guest |" "| 24 hours |  |"
expect "wait without an expiry path fails" 1 "has an expiry path" no-expiry.md

mutate no-lock-release.md "cleared by ConfirmTable or ReleaseTable; a hold older than 36 hours is released by a sweeper" "cleared by ConfirmTable"
expect "semantic lock without a stale release fails" 1 "semantic lock says what clears it and how a stale one is released" no-lock-release.md

mutate bad-cm.md "semantic lock: table state \`held\`" "we will be careful"
expect "isolation row without a countermeasure fails" 1 "names a countermeasure" bad-cm.md

mutate no-bullet.md "- Whether guests see \"held\"; owner: product owner." "nothing"
expect "no open question bullet fails" 1 "open questions has at least one bullet" no-bullet.md

mutate cdc.md "- **Profile:** standard" "- **Profile:** standard
Consumer-Driven Contract tests (CDC) cover it."
expect "CDC used for Consumer-Driven Contract fails" 1 "'CDC' is not used" cdc.md

mutate lean.md "- **Profile:** standard" "- **Profile:** lean"
expect "lean with a saga warns but passes" 0 "WARN: lean profile" lean.md

mutate code.md "## Open Questions" '```
code
```

## Open Questions'
expect "a code block warns" 0 "WARN: a code block" code.md

expect "a file with no saga sections fails" 1 "at least one '## Saga:' section" empty.md

smoke_test_summary
