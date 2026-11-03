#!/bin/bash
# Tests skills/subdomain-distillation/scripts/validate-subdomain-classification.sh —
# a skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/subdomain-distillation/scripts/validate-subdomain-classification.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-subdomain-classification: $1"
  else
    _fail "validate-subdomain-classification: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: subdomain-classification
product: pedalpost
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-01
summary: Pedalpost subdomains; Core is matching cargo-bike riders to same-day drops.
profile: standard
traces-to: [design/event-storming/big-picture.md, strategy/vision.md]
classified-on: 2026-03-01
---

# Subdomain Classification: Pedalpost

## Classification

| Subdomain | Type | Advantage? | Complex? | Solved elsewhere? | Sourcing | Modelling | Security-sensitive slice | Revisit when |
|---|---|---|---|---|---|---|---|---|
| Rider matching | Core | Yes: shops switch for it | Yes: hills, loads, shifts | No | In-house | Domain Model | Checklist run: none | A rival matches drop times |
| Shop accounts | Supporting | No | No | No | Cheap build | Transaction Script | Shop contact details | Shops ask for sub-accounts |
| Card payments | Generic | No | Solved | Yes: payment provider | Buy | Thin integration | Handled by the provider | — |

## Domain Vision Statement

The Core is matching a cargo-bike rider to each same-day drop so that a shop's parcel arrives within two hours, weighing hills, loads and riders' shifts. Nothing off the shelf plans for cargo bikes in a hilly town.

## Highlighted Core

Event Storming area "Dispatch": DropRequested, RiderAssigned; terms Drop, Rider Shift.
EOF
expect "a complete standard classification passes and counts types" good.md 0 "INFO: 1 Core, 1 Supporting, 1 Generic"

sed 's/^classified-on: .*/classified-on: soon/' good.md > nodate.md
expect "no classified-on date fails" nodate.md 1 "FAIL: frontmatter has a \`classified-on\` date"

sed 's/^traces-to: .*/traces-to: [strategy\/features.md]/' good.md > nobp.md
expect "no Big Picture and not marked provisional fails" nobp.md 1 "FAIL: drawn from the Event Storming Big Picture"

sed 's/| Yes: hills, loads, shifts |/| |/' good.md > notest.md
expect "an unanswered test fails" notest.md 1 "FAIL: 'Rider matching': the complexity test is answered"

sed 's/| In-house | Domain Model |/| Outsource build | Domain Model |/' good.md > coreout.md
expect "an outsourced Core fails" coreout.md 1 "FAIL: 'Rider matching': Core is built in-house"

sed 's/| Buy | Thin integration |/| Outsource build | Thin integration |/' good.md > genout.md
expect "a Generic that is outsourced rather than bought fails" genout.md 1 "FAIL: 'Card payments': Generic is bought or adopted"

sed 's/| In-house | Domain Model |/| In-house | Transaction Script |/' good.md > coremod.md
expect "a Core without a Domain Model fails" coremod.md 1 "FAIL: 'Rider matching': Core gets a Domain Model"

sed 's/| Shop contact details |/| |/' good.md > nosec.md
expect "no security result fails" nosec.md 1 "FAIL: 'Shop accounts': the security checklist result is recorded"

sed 's/| Shops ask for sub-accounts |/| |/' good.md > norev.md
expect "a Supporting row with no revisit trigger fails" norev.md 1 "FAIL: 'Shop accounts': has a revisit trigger"

awk '/^## Domain Vision Statement/{exit} {print}' good.md > nodvs.md
expect "standard with no Domain Vision Statement fails" nodvs.md 1 "FAIL: standard/enterprise: a Domain Vision Statement"

sed -e 's/| Shop accounts | Supporting |/| Shop accounts | Core |/' -e 's/| Cheap build | Transaction Script |/| In-house | Domain Model |/' -e 's/| Card payments | Generic |/| Card payments | Core |/' -e 's/| Buy | Thin integration | Handled by the provider | — |/| In-house | Domain Model | Handled by the provider | x |/' good.md > manycore.md
expect "three Core subdomains warn" manycore.md 0 "WARN: 3 Core subdomains"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-subdomain-classification: no argument exits 2" || _fail "validate-subdomain-classification: no argument exits 2" "exit $code"

smoke_test_summary
