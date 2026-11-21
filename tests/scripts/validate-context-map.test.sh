#!/bin/bash
# Tests skills/bounded-context-mapping/scripts/validate-context-map.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/bounded-context-mapping/scripts/validate-context-map.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-context-map: $1"
  else
    _fail "validate-context-map: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: context-map
product: ferrylink
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-02-10
summary: Ferrylink has two contexts split where "sailing" changes meaning.
profile: standard
mode: agent-run
traces-to: [design/subdomain-classification.md, design/event-storming/big-picture.md]
---

# Context Map: Ferrylink

## Contexts

### Timetabling

| Field | Value |
|---|---|
| **Responsibility** | Plans which vessel sails when |
| **Subdomain(s)** | Timetable planning (Core) |
| **Boundary evidence** | "Sailing" is a planned departure here, a sold capacity in Booking (language documents) |
| **Language** | `design/timetabling/ubiquitous-language.md` |
| **Owns (Aggregates)** | Sailing Plan, Vessel Rota |
| **Publishes** | SailingPlanned |
| **Consumes** | — |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | none |

### Booking

| Field | Value |
|---|---|
| **Responsibility** | Sells places on sailings |
| **Subdomain(s)** | Passenger booking (Supporting) |
| **Boundary evidence** | *assumed*: "sailing" as sold capacity is inferred from one job story |
| **Language** | `design/booking/ubiquitous-language.md` |
| **Owns (Aggregates)** | Reservation, Fare |
| **Publishes** | PlaceReserved |
| **Consumes** | SailingPlanned (Timetabling) |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | none |

## External Systems

| System | Used by | What it provides |
|---|---|---|
| Payment Provider | Booking | Card payments |

## Target Map

```
Timetabling ──U──D─▶ Booking ◀─D──U── Payment Provider
```

## Relationships

| Upstream | Downstream | Pattern | Reason |
|---|---|---|---|
| Timetabling | Booking | Customer/Supplier | Booking needs plan facts on its terms |
| Payment Provider | Booking | Conformist | Adequate model; Booking isn't Core |

## Open Questions for the Product Owner

| # | Question | Why it matters | Boundary assumed meanwhile |
|---|---|---|---|
| 1 | Does sales talk about "sailings" or "crossings"? | Confirms the Booking boundary | Separate Booking context |
EOF
expect "a complete map passes and counts contexts, systems and lines" good.md 0 "INFO: 2 context(s), 1 external system(s), 2 line(s), 1 with *assumed* evidence"

sed 's/^traces-to: .*/traces-to: [design\/event-storming\/big-picture.md]/' good.md > noclass.md
expect "a map drawn without the subdomain classification fails" noclass.md 1 "FAIL: drawn from the subdomain classification"

sed 's/| "Sailing" is a planned departure here, a sold capacity in Booking (language documents) |/| |/' good.md > noevid.md
expect "a context with no boundary evidence fails" noevid.md 1 "FAIL: context 'Timetabling': boundary evidence is filled in"

sed 's/^### Booking$/### Booking Service/' good.md > techname.md
expect "a technical context name fails" techname.md 1 "FAIL: context 'Booking Service' is named with a domain noun"

sed 's/^### Booking$/### Mobile/' good.md > teamname.md
expect "a team or UI name as a context fails" teamname.md 1 "FAIL: context 'Mobile' is named with a domain noun"

sed 's/| \*\*Candidate split\*\* | none |/| **Deployable service** | timetabling-svc |/' good.md > svc.md
expect "deciding a deployable service here fails" svc.md 1 "no deployable-service field"

sed 's/| Customer\/Supplier | Booking needs plan facts on its terms |/| [ ? ] | [ ? ] |/' good.md > nopattern.md
expect "a line with no pattern fails" nopattern.md 1 "FAIL: line Timetabling → Booking: pattern filled"

sed 's/| Timetabling | Booking | Customer/| Ticketing | Booking | Customer/' good.md > unknown.md
expect "a line to an undefined context fails" unknown.md 1 "FAIL: line Ticketing → Booking: both ends are defined"

awk '/^## Open Questions/{exit} {print}' good.md > noq.md
expect "assumed evidence with no open questions fails" noq.md 1 "so open questions for the product owner are listed"

awk '/^## Target Map/{skip=1} /^## Relationships/{skip=0} !skip' good.md > notarget.md
expect "no target map fails" notarget.md 1 "FAIL: has a target map"

cat > peragg.md <<'EOF'
---
name: context-map
product: ferrylink
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-02-10
summary: One context per Aggregate.
mode: agent-run
traces-to: [design/subdomain-classification.md]
---

## Contexts

### Sailing Plan

| Field | Value |
|---|---|
| **Responsibility** | x |
| **Subdomain(s)** | x (Core) |
| **Boundary evidence** | x |
| **Language** | x |
| **Owns (Aggregates)** | Sailing Plan |

### Reservation

| Field | Value |
|---|---|
| **Responsibility** | x |
| **Subdomain(s)** | x (Core) |
| **Boundary evidence** | x |
| **Language** | x |
| **Owns (Aggregates)** | Reservation |

### Fare

| Field | Value |
|---|---|
| **Responsibility** | x |
| **Subdomain(s)** | x (Core) |
| **Boundary evidence** | x |
| **Language** | x |
| **Owns (Aggregates)** | Fare |

## Target Map

```
Sailing Plan ──U──D─▶ Reservation ──U──D─▶ Fare
```

## Relationships

| Upstream | Downstream | Pattern | Reason |
|---|---|---|---|
| Sailing Plan | Reservation | Partnership | x |
EOF
expect "one context per Aggregate warns" peragg.md 0 "WARN: every context owns exactly one Aggregate"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-context-map: no argument exits 2" || _fail "validate-context-map: no argument exits 2" "exit $code"

smoke_test_summary
