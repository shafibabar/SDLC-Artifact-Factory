#!/bin/bash
# Tests skills/command-catalog/scripts/validate-command-catalog.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/command-catalog/scripts/validate-command-catalog.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-command-catalog: $1"
  else
    _fail "validate-command-catalog: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: command-catalog
product: hivewatch
bounded-context: Apiary
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-04-11
summary: Apiary accepts InspectHive from beekeepers and QuarantineHive from the disease Policy.
profile: standard
traces-to: [design/apiary/aggregates.md]
---

# Command Catalog: Apiary

## Commands

| Command | Aggregate | Issued by | Records |
|---|---|---|---|
| InspectHive | Hive | beekeeper | HiveInspected |
| QuarantineHive | Hive | Policy | HiveQuarantined |

## Command: InspectHive

| Field | Value |
|---|---|
| **Intent** | A beekeeper records what they found when they opened a hive |
| **Aggregate** | Hive — by hiveId |
| **Issued by** | beekeeper assigned to the apiary |
| **Records** | HiveInspected |
| **Idempotency key** | client request ID kept across retries of one inspection |
| **On a duplicate** | returns the first outcome, rejection included; keys kept 7 days |
| **Already in effect** | not applicable — each inspection is new |
| **Concurrency** | none needed — the rules are re-checked on the current state |
| **Caller needs** | the outcome now |
| **Source** | design/event-storming/process-inspection.md |

### Inputs

| Input | Meaning (in the language) | From | Input rule (checked before the Aggregate) |
|---|---|---|---|
| hiveId | the hive opened | target | present |
| broodFrames | frames with brood seen | request | 0 to 30 |
| inspectorId | who inspected | authenticated context | — |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| Brood frames must be between 0 and 30 | invalid input | input |
| A quarantined hive can only be inspected by the bee inspector | rule violated | Aggregate |
| No such hive | not found | loading the target |

## Command: QuarantineHive

| Field | Value |
|---|---|
| **Intent** | Stop all movement of a hive after a notifiable disease is found |
| **Aggregate** | Hive — by hiveId |
| **Issued by** | Policy: Whenever DiseaseConfirmed, then QuarantineHive |
| **Records** | HiveQuarantined |
| **Idempotency key** | the DiseaseConfirmed event ID |
| **On a duplicate** | returns the first outcome; keys kept 30 days |
| **Already in effect** | succeeds and records nothing — the hive is already held |
| **Concurrency** | none needed — quarantine applies whatever the hive's state |
| **Caller needs** | an acknowledgement now, the outcome via event |
| **Source** | design/apiary/domain-event-catalog.md |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| No such hive | not found | loading the target |
EOF
expect "a complete catalog passes and counts Commands" good.md 0 "INFO: 2 Command(s)"

sed 's/InspectHive/UpdateHive/g' good.md > crud.md
expect "a CRUD verb as the intent fails" crud.md 1 "FAIL: UpdateHive: no CRUD verb as the intent (Update)"

sed 's/InspectHive/InspectedHive/g' good.md > past.md
expect "a past-tense name fails the imperative check" past.md 1 "FAIL: InspectedHive: imperative"

sed 's/InspectHive/GetHive/g' good.md > query.md
expect "a query verb fails" query.md 1 "FAIL: GetHive: not a query verb"

sed 's/InspectHive/ProcessHive/g' good.md > tech.md
expect "a technical verb fails" tech.md 1 "FAIL: ProcessHive: no technical verb"

sed 's/InspectHive/InspectHiveCommand/g' good.md > suffix.md
expect "a Command suffix fails" suffix.md 1 "FAIL: InspectHiveCommand: no 'Command' suffix"

sed 's/^| \*\*Aggregate\*\* | Hive — by hiveId |$/| **Aggregate** | Hive and Apiary — by id |/' good.md > twoagg.md
expect "two target Aggregates fail" twoagg.md 1 "targets one Aggregate"

sed '0,/| \*\*Records\*\* | HiveInspected |/s//| **Records** | none |/' good.md > norec.md
expect "a Command that records nothing fails" norec.md 1 "FAIL: InspectHive: records an event"

sed 's/| \*\*On a duplicate\*\* | returns the first outcome, rejection included; keys kept 7 days |/| **On a duplicate** | re-runs the Command against current state |/' good.md > rerun.md
expect "a duplicate that re-runs fails" rerun.md 1 "FAIL: InspectHive: a duplicate returns the first outcome"

sed 's/| \*\*Issued by\*\* | Policy: Whenever DiseaseConfirmed, then QuarantineHive |/| **Issued by** | Policy on disease |/' good.md > nopolicy.md
expect "a Policy issuer not written as a policy fails" nopolicy.md 1 "a Policy issuer is written as 'Whenever"

sed 's/| inspectorId | who inspected | authenticated context | — |/| inspectorId | who inspected | request | — |/' good.md > body.md
expect "identity taken from the request fails" body.md 1 "FAIL: InspectHive: input 'inspectorId' comes from the authenticated context"

sed 's/| inspectorId | who inspected | authenticated context | — |/| inspectorId | who inspected | authenticated context | — |\n| newKeeperId | who will keep the hive next | request | present |/' good.md > target.md
expect "a person named as an ordinary input may come from the request" target.md 0 "INFO: 2 Command(s)"

sed 's/| rule violated | Aggregate |/| rule violated | API handler |/' good.md > edge.md
expect "a business rule checked outside the Aggregate fails" edge.md 1 "is checked in the Aggregate"

sed 's/| invalid input | input |/| bad data | input |/' good.md > kind.md
expect "an unknown rejection kind fails" kind.md 1 "has a known kind"

sed 's/| \*\*Concurrency\*\* | none needed — the rules are re-checked on the current state |/| **Concurrency** | |/' good.md > noconc.md
expect "a missing concurrency decision fails" noconc.md 1 "FAIL: InspectHive: 'concurrency' is filled in"

sed 's/| \*\*Idempotency key\*\* | the DiseaseConfirmed event ID |/| **Idempotency key** | natural: one quarantine per hive |/' good.md > polkey.md
expect "a Policy without an event-ID key warns" polkey.md 0 "WARN: QuarantineHive: issued by a Policy"

sed 's/^| QuarantineHive | Hive | Policy | HiveQuarantined |$/| QuarantineHive | Hive | Policy | HiveQuarantined |\n| MoveHive | Hive | beekeeper | HiveMoved |/' good.md > orphan.md
expect "a summary row with no Command block fails" orphan.md 1 "missing: MoveHive"

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

{ cat good.md; printf '\nExposed as `POST /hives/{id}/inspections`, answering 202 Accepted.\n'; } > http.md
expect "HTTP mapping in the catalog fails" http.md 1 "FAIL: no HTTP mapping"

{ cat good.md; printf '\n```go\ntype InspectHive struct{}\n```\n'; } > code.md
expect "code in the catalog fails (D047-10)" code.md 1 "FAIL: no code or DDL"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-command-catalog: no argument exits 2" || _fail "validate-command-catalog: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-command-catalog: a missing file exits 2" || _fail "validate-command-catalog: a missing file exits 2" "exit $code"

smoke_test_summary
