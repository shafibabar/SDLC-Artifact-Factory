#!/bin/bash
# Tests skills/component-diagram/scripts/validate-component-diagram.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/component-diagram/scripts/validate-component-diagram.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> [substring] -- <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-component-diagram: $label"
  else
    _fail "validate-component-diagram: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: component-diagram
product: tidewatch
service: gauge
bounded-context: Gauge
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-02-01
summary: The gauge service with an adapter around the harbour sensor feed.
traces-to: [design/architecture/container-diagram.md]
---

# Component diagram for Gauge Service

**Readers:** backend-engineer, reviewers
**Question it answers:** what is inside the gauge service and which way do dependencies point?

## Container Context

`gauge` (Go, chi): reads and writes Gauge DB, calls the Harbour Sensor Feed.

## Departures from the Default

- Anti-corruption adapter around the Harbour Sensor Feed

## Diagram

```
+-- Gauge Service [Container: API, Go, chi] ----------------+
|  Gauge Handlers [Component: entry point]                  |
|     | calls                                               |
|     v                                                     |
|  Gauge Use Cases [Component: use cases] --uses--> Gauge Domain [Component: domain] |
|  Sensor Adapter [Component: adapter] - - implements - - > Gauge Domain |
+-----------------------------------------------------------+
   Sensor Adapter --- reads tide levels [HTTPS] ---> Harbour Sensor Feed
```

## Key

- `────▶` depends on (an arrow from the dependent component); `- - -▶` implements a port

## Element Catalog

### Components

| Component | Role | Package or module | Interface presented | Responsibility |
|---|---|---|---|---|
| Gauge Handlers | entry point | handlers/http | routes on /gauges | Decode requests |
| Gauge Use Cases | use cases | application | RecordReading | Orchestrate a reading |
| Gauge Domain | domain | domain | Gauge, SensorFeed port | Invariants and ports |
| Sensor Adapter | adapter | infrastructure/sensor | implements SensorFeed | Translate the feed |

### Relationships

| From | To | Nature | Direction rationale |
|---|---|---|---|
| Gauge Handlers | Gauge Use Cases | calls | inward |
| Gauge Use Cases | Gauge Domain | uses via port | inward |
| Sensor Adapter | Gauge Domain | implements | inversion |
| Sensor Adapter | Harbour Sensor Feed | HTTPS | inter-process |

## Dependency Rule

The SensorFeed port is declared in the domain; the domain imports only the standard library.

## Fitness Function

- **Check:** the arch target's import check fails the build on a forbidden import

## Variability

Pooled per multi-tenancy-design; the structure is the same in every region.

## Rationale

- The feed's model changes with each sensor vendor, so it is translated in one adapter.

## Open Questions

- none
EOF

expect "a complete diagram passes" 0 "" good.md

sed '/^- Anti-corruption adapter around the Harbour Sensor Feed$/d' good.md > nodep.md
expect "no departure from the default fails (skip instead)" 1 "names at least one departure" nodep.md

sed 's/^|     | calls  /|     | 1. calls/' good.md > step.md
sed -i 's/^|  Gauge Handlers \[Component: entry point\]  /|  (1) Gauge Handlers [Component: entry point]/' step.md
expect "step numbers on the picture fail" 1 "no step numbers" step.md

sed 's/--uses-->/<--uses-->/' good.md > twoway.md
expect "a two-way arrow fails" 1 "no two-way arrows" twoway.md

{ cat good.md | sed 's/^   Sensor Adapter --- reads tide levels \[HTTPS\] ---> Harbour Sensor Feed$/+-- Harbour Service [Container: API, Go] ---+\n   Sensor Adapter --- reads [HTTPS] ---> Harbour Sensor Feed/'; } > twoframes.md
expect "two container boundaries fail" 1 "exactly one container boundary" twoframes.md

sed 's/^| Gauge Handlers | Gauge Use Cases | calls | inward |$/| Gauge Handlers | Gauge Use Cases | HTTP | inward |/' good.md > proto.md
expect "a protocol between two components fails" 1 "no protocol between two components" proto.md

sed 's/^| Gauge Use Cases | Gauge Domain | uses via port | inward |$/| Gauge Use Cases | Gauge Domain | uses via port | inward |\n| Gauge Domain | Gauge Use Cases | calls | outward |/' good.md > cycle.md
expect "two components depending on each other fail" 1 "no two components depend on each other" cycle.md

sed 's/^- \*\*Check:\*\*.*$/- **Check:** [none]/' good.md > noff.md
expect "no fitness function fails" 1 "names a fitness function" noff.md

sed 's/^The SensorFeed port is declared in the domain; the domain imports only the standard library\.$/The layers are respected./' good.md > nodr.md
expect "no Dependency Rule statement fails" 1 "where ports are declared" nodr.md

sed 's/^Pooled per multi-tenancy-design; the structure is the same in every region\.$/Each tenant gets its own stamp./' good.md > stamp.md
expect "an assumed per-tenant stamp fails" 1 "doesn't assume a per-tenant stamp" stamp.md

sed 's/^| Sensor Adapter | adapter | infrastructure\/sensor |/| Sensor Adapter | struct | infrastructure\/sensor |/' good.md > struct.md
expect "a component typed as a struct fails" 1 "grouping behind an interface" struct.md

awk 'BEGIN{skip=0} /^## Diagram$/{print; print ""; print "```mermaid"; print "C4Component"; print "```"; skip=1; next} skip && /^## Key$/{skip=0} !skip' good.md > mermaidonly.md
expect "Mermaid alone fails (ASCII primary)" 1 "ASCII picture" mermaidonly.md

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" 1 "FAIL: frontmatter has" notrace.md

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-component-diagram: no argument exits 2" || _fail "validate-component-diagram: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-component-diagram: a missing file exits 2" || _fail "validate-component-diagram: a missing file exits 2" "exit $code"

smoke_test_summary
