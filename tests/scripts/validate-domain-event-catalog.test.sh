#!/bin/bash
# Tests skills/domain-event-catalog/scripts/validate-domain-event-catalog.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/domain-event-catalog/scripts/validate-domain-event-catalog.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-domain-event-catalog: $1"
  else
    _fail "validate-domain-event-catalog: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: domain-event-catalog
product: seedswap
bounded-context: Exchanges
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-02
summary: Exchanges publishes SeedPacketClaimed to Postage; ClaimHoldExtended stays internal.
profile: standard
traces-to: [design/exchanges/aggregates.md]
---

# Domain Event Catalog: Exchanges

## Events

| Event | Aggregate | Visibility | Consumers |
|---|---|---|---|
| SeedPacketClaimed | Listing | published | Postage |
| ClaimHoldExtended | Listing | internal | none |

## Event: SeedPacketClaimed

| Field | Value |
|---|---|
| **Means** | A member claimed a listed seed packet |
| **Aggregate** | Listing |
| **Raised by** | Command ClaimPacket |
| **Visibility** | published |
| **Published as** | see design/data/event-schemas.md |
| **Ordering** | per Aggregate |
| **Retention need** | consumer replay 30 days — Postage rebuilds its queue |
| **Sensitive data** | none |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| listingId | the listing | key |
| claimantId | who claimed it | Postage addresses the parcel |

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| Postage | Whenever SeedPacketClaimed, then QueuePostage | listingId | tolerates out-of-order replay |

## Event: ClaimHoldExtended

| Field | Value |
|---|---|
| **Means** | The lister gave the claimant more time to collect |
| **Aggregate** | Listing |
| **Raised by** | Command ExtendHold |
| **Visibility** | internal |
| **Published as** | not published — only Exchanges reacts |
| **Ordering** | per Aggregate |
| **Retention need** | operational only — a week |
| **Sensitive data** | none |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| listingId | the listing | key |
| holdUntil | the new deadline | the expiry timer |
EOF
expect "a complete catalog passes and counts events" good.md 0 "INFO: 2 event(s), 1 published"

sed 's/SeedPacketClaimed/SeedPacketUpdated/g' good.md > crud.md
expect "a CRUD verb as the fact fails" crud.md 1 "FAIL: SeedPacketUpdated: no CRUD or technical verb as the fact"

sed 's/SeedPacketClaimed/ClaimSeedPacket/g' good.md > command.md
expect "a command-shaped name fails the past-tense check" command.md 1 "FAIL: ClaimSeedPacket: past tense"

sed 's/SeedPacketClaimed/SeedPacketClaimedV2/g' good.md > ver.md
expect "a version suffix fails" ver.md 1 "FAIL: SeedPacketClaimedV2: no version suffix"

sed 's/SeedPacketClaimed/seed_packet_claimed/g' good.md > snake.md
expect "a non-PascalCase name fails" snake.md 1 "FAIL: seed_packet_claimed: PascalCase"

sed 's/| listingId | the listing | key |/| listingId | the listing | key |\n| occurredAt | when | ordering |/' good.md > env.md
expect "an envelope field in the payload fails" env.md 1 "payload field 'occurredAt' is not an envelope attribute"

sed 's/| Postage | Whenever SeedPacketClaimed, then QueuePostage | listingId |/| Postage | queues postage | listingId |/' good.md > nopolicy.md
expect "a reaction not written as a policy fails" nopolicy.md 1 "FAIL: SeedPacketClaimed → Postage: reaction written as a policy"

sed 's/| Postage | Whenever SeedPacketClaimed, then QueuePostage | listingId |/| Postage | Whenever SeedPacketClaimed, then QueuePostage | |/' good.md > noidem.md
expect "a reaction with no idempotency key fails" noidem.md 1 "FAIL: SeedPacketClaimed → Postage: says what the reaction is idempotent on"

sed 's/| \*\*Published as\*\* | not published — only Exchanges reacts |/| **Published as** | yes |/' good.md > inttrans.md
expect "an internal event with no translation or reason fails" inttrans.md 1 "FAIL: ClaimHoldExtended: internal or stored event says how it is published"

sed 's#| \*\*Published as\*\* | see design/data/event-schemas.md |#| **Published as** | yes |#' good.md > nowire.md
expect "a published event with no wire contract pointer fails" nowire.md 1 "FAIL: SeedPacketClaimed: published event points to its wire contract"

sed 's/| \*\*Retention need\*\* | operational only — a week |/| **Retention need** | |/' good.md > noret.md
expect "a missing retention need fails" noret.md 1 "FAIL: ClaimHoldExtended: 'retention need' is filled in"

sed '/^| holdUntil /d' good.md > thin.md
expect "an ID-only payload warns" thin.md 0 "WARN: ClaimHoldExtended: one payload field"

sed 's/^| ClaimHoldExtended | Listing | internal | none |$/| ClaimHoldExtended | Listing | internal | none |\n| SeedPacketPosted | Listing | published | Members |/' good.md > orphan.md
expect "a summary row with no event block fails" orphan.md 1 "missing: SeedPacketPosted"

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

{ cat good.md; printf '\n```sql\nCREATE TABLE outbox_events (id uuid);\n```\n'; } > ddl.md
expect "DDL in the catalog fails (D047-10)" ddl.md 1 "FAIL: no code or DDL"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-domain-event-catalog: no argument exits 2" || _fail "validate-domain-event-catalog: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-domain-event-catalog: a missing file exits 2" || _fail "validate-domain-event-catalog: a missing file exits 2" "exit $code"

smoke_test_summary
