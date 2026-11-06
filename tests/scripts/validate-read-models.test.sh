#!/bin/bash
# Tests skills/read-model-design/scripts/validate-read-models.sh — a skill-owned
# script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/read-model-design/scripts/validate-read-models.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-read-models: $1"
  else
    _fail "validate-read-models: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: read-model-design
product: bookbarrow
bounded-context: Lending
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-02-11
summary: Lending answers members from its tables; the van stock board is projected, 20 s behind, rebuilt from the archive.
profile: standard
traces-to: [design/architecture/cqrs-decisions.md, design/lending/aggregates.md]
---

# Read Models: Lending

## Read Models

| Read Model | Answers | Rung | Staleness accepted |
|---|---|---|---|
| MyLoans | a member: what I have out and when it is due | simple read model | immediate |
| VanStockBoard | a driver: which titles are on the van today | projection | 20 seconds |

## Read Model: MyLoans

| Field | Value |
|---|---|
| **Answers** | a member: what I have out and when it is due |
| **Rung** | simple read model |
| **Built from** | loan table joined to title, through a query type |
| **Filters and order** | member; by due date |
| **Tenant scope** | single library service |

### Fields

| Field | Meaning | Source |
|---|---|---|
| title | the book | title.name |
| due | the due date | loan.due_on |

## Read Model: VanStockBoard

| Field | Value |
|---|---|
| **Answers** | a driver: which titles are on the van today |
| **Rung** | projection |
| **Mechanic** | from published events — the outbox publishes loan events |
| **Store** | Lending's database, one row per van and title |
| **Keyed on** | van, title |
| **Staleness accepted** | 20 seconds |
| **Freshness shown** | an as-of time on the board |
| **Read-your-writes** | the Command returns the version; the driver's screen shows pending until applied |
| **Idempotency** | processed-event record for every event |
| **Lag alert** | 10 seconds behind |
| **Rebuild source** | outbox archive, every loan event since launch |
| **Rebuild** | build into a copy beside the live board, catch up, switch in one step; never patched by hand |
| **Old event types** | none yet |
| **Tenant scope** | single library service |

### Fields

| Field | Meaning | Source | Copied from |
|---|---|---|---|
| title | the book's name | TitleCatalogued.name | Catalogue (its change event: TitleRenamed) |
| copiesOnVan | copies aboard | BookLoaded less BookUnloaded | — |

### Events

| Event | Effect on the view |
|---|---|
| BookLoaded | adds one copy to the van's row |
| BookUnloaded | removes one copy |
| TitleRenamed | re-projects the title on every row holding it |
EOF
expect "a complete document passes and counts Read Models" good.md 0 "INFO: 2 Read Model(s), 1 projected"

sed '/^traces-to:/s/design\/architecture\/cqrs-decisions.md, //' good.md > notrace.md
expect "not tracing to cqrs-decisions fails" notrace.md 1 "traces-to names cqrs-decisions.md"

sed 's/^| \*\*Built from\*\* | loan table.*$/| **Built from** | loads the Loan Aggregate for each row |/' good.md > aggload.md
expect "a rung-1 entry that loads the Aggregate fails" aggload.md 1 "never by loading the Aggregate"

sed 's/^| \*\*Rebuild\*\* | .*$/| **Rebuild** | patch the drifted rows by hand with SQL |/' good.md > patch.md
expect "a hand patch as the rebuild fails" patch.md 1 "the rebuild is from events, not a hand patch or a live truncate"

sed 's/^| \*\*Rebuild\*\* | .*$/| **Rebuild** | truncate the board and replay into it |/' good.md > trunc.md
expect "truncating the live view fails" trunc.md 1 "not a hand patch or a live truncate"

sed 's/^| \*\*Rebuild source\*\* | .*$/| **Rebuild source** | the loans topic on the broker |/' good.md > topic.md
expect "a topic as rebuild source without its retention fails" topic.md 1 "states its retention"

sed 's/^| \*\*Rebuild source\*\* | .*$/| **Rebuild source** | the loans topic, retention 7 days: a rebuild cannot recover older loans |/' good.md > topicok.md
expect "a topic with its retention stated passes" topicok.md 0

sed 's/^| \*\*Store\*\* | .*$/| **Store** | a cache in front of the table |/' good.md > cache.md
expect "a cache without a time-to-live fails" cache.md 1 "a cache states its time-to-live"

sed 's/^| \*\*Store\*\* | .*$/| **Store** | Lending database; no cache |/' good.md > nocache.md
expect "'no cache' is not a cache" nocache.md 0

sed 's/^| \*\*Staleness accepted\*\* | 20 seconds |$/| **Staleness accepted** | immediate |/' good.md > stale.md
expect "an asynchronous projection claiming immediate consistency fails" stale.md 1 "accepts some staleness"

sed 's/^| title | the book.s name | TitleCatalogued.name | .*$/| title | the book name | TitleCatalogued.name | catalogue |/' good.md > copied.md
expect "a copied value with no change event fails" copied.md 1 "names the event that changes it"

sed 's/^| BookUnloaded | removes one copy |$/| BookUnloaded | removes one copy and sends the branch an email |/' good.md > sidefx.md
expect "a projector side effect fails" sidefx.md 1 "a projector only writes its view"

sed '/^### Events$/,$d' good.md > noevents.md
expect "a projection with no events fails" noevents.md 1 "has an Events table"

sed 's/^| VanStockBoard | a driver: which titles are on the van today | projection | 20 seconds |$/| VanStockBoard | a driver | simple read model | immediate |/' good.md > rungmis.md
expect "a summary rung that differs from the block fails" rungmis.md 1 "the summary rung matches its block"

sed 's/^| VanStockBoard | a driver: which titles are on the van today | projection | 20 seconds |$/&\n| OverdueLetters | staff | simple read model | immediate |/' good.md > orphan.md
expect "a summary row with no block fails" orphan.md 1 "missing: OverdueLetters"

sed 's/^| \*\*Rung\*\* | projection |$/| **Rung** | full CQRS |/' good.md > rung.md
expect "an unknown rung fails" rung.md 1 "rung is 'simple read model' or 'projection'"

sed '/^| \*\*Lag alert\*\*/d; /^| \*\*Old event types\*\*/d' good.md > warns.md
expect "a missing lag alert and old-event line only warn" warns.md 0 "WARN: VanStockBoard: no lag alert"

{ cat good.md; printf '\n```sql\nCREATE TABLE van_stock_board (van int);\n```\n'; } > code.md
expect "code in the document fails (D047-10)" code.md 1 "FAIL: no code or DDL"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-read-models: no argument exits 2" || _fail "validate-read-models: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-read-models: a missing file exits 2" || _fail "validate-read-models: a missing file exits 2" "exit $code"

smoke_test_summary
