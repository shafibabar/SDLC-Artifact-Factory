#!/bin/bash
# Tests skills/domain-storytelling/scripts/validate-domain-story.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/domain-storytelling/scripts/validate-domain-story.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-domain-story: $1"
  else
    _fail "validate-domain-story: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: domain-story-coarse-hire
product: kayakhire
scenario: Sam hires a kayak for the afternoon
granularity: coarse-grained
point_in_time: as-is
purity: pure
run: agent-run
variant_of: none
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-04-01
summary: Kayak hire today, coarse as-is pure, agent-run; 3 sentences, 1 assumed.
traces-to: [ideate/personas.md, ideate/job-stories.md]
---

# Domain Story: Sam hires a kayak

## The Story

| # | Actor | Activity | Work object | To (recipient) | Annotation | Source |
|---|---|---|---|---|---|---|
| 1 | Customer | asks for | a kayak | Hire Assistant | At the hut | job-stories J1 |
| 2 | Hire Assistant | gives | the buoyancy aid | Customer | Sized by eye | personas (Ola) |
| 3 | Customer | returns | the kayak | Hire Assistant | — | *assumed* |

## Groups (candidate boundaries)

| Group | Sentences | Hint: word changes · role takes over · pace or trigger changes · hand-over |
|---|---|---|
| Hut | 1–3 | Hand-over at the hut |

## Open Questions for the Product Owner

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | Who checks the kayak on return? | Actor of sentence 3 | The hire assistant |

## Retelling (agent-run: for the product owner to check)

1. The customer asks the hire assistant for a kayak.
2. The hire assistant gives the customer a buoyancy aid.
3. The customer returns the kayak to the hire assistant.
EOF
expect "a complete agent-run coarse story passes and counts assumed sentences" good.md 0 "INFO: 3 sentence(s), 1 *assumed*"

sed 's/^purity: pure/purity: annotated/' good.md > annotated.md
expect "'annotated' is not a purity value" annotated.md 1 "FAIL: purity is pure or digitalised"

sed 's/^point_in_time: as-is/point_in_time: as-is and to-be/' good.md > mixed.md
expect "a story mixing as-is and to-be fails" mixed.md 1 "FAIL: point_in_time is as-is or to-be"

sed 's/^| 3 | Customer | returns/| 2a | Customer | returns/' good.md > substep.md
expect "a numbered sub-step fails" substep.md 1 "FAIL: sentence 2a: no numbered sub-steps"

sed 's/| 1 | Customer | asks for |/| 1 | the system | asks for |/' good.md > system.md
expect "'the system' as an actor fails" system.md 1 "FAIL: sentence 1: the actor is named, not 'the system'"

sed 's/| personas (Ola) |/| |/' good.md > nosource.md
expect "a sentence with no source fails" nosource.md 1 "FAIL: sentence 2: the source is filled in"

{ cat good.md; printf '\nDraw a decision diamond at step 2 with a yes branch.\n'; } > diamond.md
expect "a decision diamond fails" diamond.md 1 "FAIL: no decision diamond"

sed 's/| Hand-over at the hut |/| |/' good.md > nohint.md
expect "a group with no hint fails" nohint.md 1 "FAIL: every group records its hint"

awk '/^## Open Questions/{skip=1} /^## Retelling/{skip=0} !skip' good.md > noq.md
expect "assumed sentences with no open questions fail" noq.md 1 "are *assumed*, so open questions"

awk '/^## Retelling/{exit} {print}' good.md > noretell.md
expect "an agent-run story with no retelling fails" noretell.md 1 "FAIL: agent-run story writes out the retelling"

sed 's/| a kayak | Hire Assistant |/| booking system | Hire Assistant |/' good.md > puresw.md
expect "software in a pure story warns but does not fail" puresw.md 0 "WARN: sentence 1:"

{ cat good.md; printf '\n```go\ntype Kayak struct{}\n```\n'; } > code.md
expect "code in a design artifact fails" code.md 1 "FAIL: no code in a design artifact"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-domain-story: no argument exits 2" || _fail "validate-domain-story: no argument exits 2" "exit $code"

smoke_test_summary
