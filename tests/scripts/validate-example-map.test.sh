#!/bin/bash
# Tests skills/example-mapping/scripts/validate-example-map.sh — a skill-owned
# script exercised directly with a file-path CLI arg. The passing fixture is
# built here, never from the skill's examples; the template is used only to
# prove that an unfilled one fails.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SKILL="$REPO_ROOT/skills/example-mapping"
VALIDATE="$SKILL/scripts/validate-example-map.sh"
cd "$SCRATCH_DIR"
mkdir -p ready open case

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -F -- "$sub" >/dev/null; }; then
    _pass "validate-example-map: $label"
  else
    _fail "validate-example-map: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <src> <dest> <old> <new> [<old> <new> ...]
  python3 - "$@" <<'PY'
import sys
src, dest, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
t = open(src).read()
for old, new in zip(pairs[::2], pairs[1::2]):
    assert old in t, "fixture missing: " + old
    t = t.replace(old, new, 1)
open(dest, "w").write(t)
PY
}

# bad <label> <substring> <old> <new> [...]: break the ready map, expect FAIL
bad() { local label="$1" sub="$2"; shift 2
  mutate ready/US-4.md case/US-4.md "$@" || { _fail "validate-example-map: $label" "fixture"; return; }
  expect "$label" 1 "$sub" case/US-4.md; }
# badopen: the same against the not-ready map
badopen() { local label="$1" sub="$2"; shift 2
  mutate open/US-4.md case/US-4.md "$@" || { _fail "validate-example-map: $label" "fixture"; return; }
  expect "$label" 1 "$sub" case/US-4.md; }

cat > ready/US-4.md <<'FIXTURE'
---
name: example-map
product: shelfmark
story-id: US-4
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Renewing a loan, one rule, ready.
profile: lean
run: agent-run
readiness: ready
traces_to: ideate/user-stories.md (US-4, BR-1)
---

# Example Map: US-4 Renew a loan

## Story

As a borrower, I want to renew a loan, so that I can finish the book.

- Seed example: Ana renews a loan due 3 May and it becomes due 24 May.
- Cited rules and targets: BR-1

## How This Map Was Made

Agent-run: one agent (requirements-analyst) played all three perspectives in turn; no workshop was held.

- Read: ideate/user-stories.md (US-4)

| Perspective | What it raised |
|---|---|
| Customer | R1.E1 |
| Developer | R1.E3 |
| Tester | R1.E2 |

## Rules and Examples

### R1: A loan can be renewed once (BR-1)
- Source: ideate/user-stories.md (BR-1)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Ana renews a loan due 3 May | It is due 24 May | ideate/user-stories.md (US-4) |
| R1.E2 | Negative | Ana renews the same loan again | Refused as already renewed | ideate/user-stories.md (BR-1) |
| R1.E3 | Edge | Ana renews on 3 May, the due date | It is due 24 May | product owner, 2026-11-25 (Q-1) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | Can a loan be renewed on its due date? | R1 | Decides the limit | Yes | answered | Yes — product owner, 2026-11-25 |

## Split Check

- Rules: 1 · Open questions: 0
- Decision: keep; one behaviour

## Readiness

**Verdict:** Ready
- Blocking: none
FIXTURE

OPENROW="| Q-1 | Can a loan be renewed on its due date? | R1 | Decides the limit | Yes | open | — |"
mutate ready/US-4.md open/US-4.md \
  "| Q-1 | Can a loan be renewed on its due date? | R1 | Decides the limit | Yes | answered | Yes — product owner, 2026-11-25 |" "$OPENROW" \
  "| product owner, 2026-11-25 (Q-1) |" "| assumption (Q-1) |" \
  "readiness: ready" "readiness: not-ready" \
  "Open questions: 0" "Open questions: 1" \
  "**Verdict:** Ready" "**Verdict:** Not ready" \
  "- Blocking: none" "- Blocking: Q-1"

expect "a ready map passes" 0 "0 check(s) failed" ready/US-4.md
expect "a truthful not-ready map passes" 0 "0 check(s) failed" open/US-4.md
cp "$SKILL/templates/example-map.md" case/US-4.md
expect "the unfilled template fails" 1 "FAIL: no unfilled <placeholder>" case/US-4.md
expect "missing file is a usage error" 2 "file not found" nope.md
OUT="$("$VALIDATE" 2>&1)"; CODE=$?
if [ "$CODE" -eq 2 ]; then _pass "validate-example-map: no argument is a usage error"; else _fail "validate-example-map: no argument" "exit $CODE"; fi

cp ready/US-4.md case/US-9.md
expect "file name must match the story" 1 "FAIL: file name is <story-id>.md" case/US-9.md

bad "missing frontmatter key" "frontmatter has 'summary'" "summary: Renewing a loan, one rule, ready." "summary:"
bad "unknown profile" "profile is lean" "profile: lean" "profile: tiny"
bad "old sprint field" "ready-for-sprint" "readiness: ready" $'readiness: ready\nready-for-sprint: yes'
bad "placeholder left in" "no unfilled <placeholder>" "It is due 24 May |" "<what is then true> |"
bad "Given/When/Then in the map" "no Given/When/Then" "## Split Check" $'Given a loan, When renewed, Then it moves.\n\n## Split Check'
bad "criterion id in the map" "no criterion IDs" "Decision: keep; one behaviour" "Decision: keep; see AC-US-4.1"
bad "section missing" "section 'split check'" "## Split Check" "## Sizing"
bad "no seed example" "story states the seed example" "- Seed example:" "- Note:"
bad "claims a session" "says no workshop" "; no workshop was held." " in a workshop."
bad "one-agent honesty missing" "says one agent" "one agent (requirements-analyst)" "the team"
bad "workshop without participants" "names its participants" "run: agent-run" "run: workshop"
bad "perspective missing" "perspective 'tester'" "| Tester | R1.E2 |" ""
bad "no rule" "at least one rule" "### R1: A loan can be renewed once (BR-1)" "A loan can be renewed once (BR-1)"
bad "rule without source" "R1: has a source" $'- Source: ideate/user-stories.md (BR-1)\n' ""
bad "unknown example type" "R1.E1: type is" "| Happy |" "| Positive |"
bad "empty outcome" "R1.E2: case, expected outcome and source" "| Refused as already renewed |" "|  |"
bad "example restates the rule" "R1.E2: does not just restate" "| Ana renews the same loan again |" "| A loan can be renewed once (BR-1) |"
bad "duplicate example id" "unique R1.En id" "| R1.E2 | Negative" "| R1.E1 | Negative"
bad "ready without a negative example" "ready: R1 has no Negative example" "| Negative |" "| Happy |"
bad "ready without an edge example" "ready: the story has no Edge example" "| Edge |" "| Happy |"
bad "ready with an assumption" "ready: no assumption" "| product owner, 2026-11-25 (Q-1) |" "| assumption (Q-1) |"
bad "ready with an open question" "ready: no open question" "| answered | Yes — product owner, 2026-11-25 |" "| open | — |"
bad "agent answers a question" "answered by the product owner" "Yes — product owner, 2026-11-25" "Yes — requirements-analyst, 2026-11-25"
bad "answer without a date" "answered by the product owner" "Yes — product owner, 2026-11-25" "Yes — product owner"
bad "moved without another story" "moved to another story" "| answered | Yes —" "| moved | Yes —"
bad "unknown status" "status is open, answered or moved" "| answered |" "| deferred |"
bad "question without recommendation" "recommendation are filled" "| Decides the limit | Yes |" "| Decides the limit | — |"
bad "wrong rule count" "split check counts" "Rules: 1" "Rules: 2"
bad "no split decision" "states a decision" "Decision: keep; one behaviour" "Decision: —"
bad "verdict disagrees" "verdict matches" "**Verdict:** Ready" "**Verdict:** Not ready"
badopen "open question given an answer" "open question has no answer" "| open | — |" "| open | Probably yes |"
badopen "assumption without a question" "assumption names an open question" "| assumption (Q-1) |" "| assumption |"
badopen "assumption points at no such question" "assumption names an open question" "| assumption (Q-1) |" "| assumption (Q-7) |"
badopen "unknown outcome without a question" "unknown names an open question" "| Refused as already renewed |" "| unknown |"
badopen "blocking line omits the question" "blocking line lists" "- Blocking: Q-1" "- Blocking: none"
badopen "not-ready with nothing blocking" "at least one open question says" "| open | — |" "| answered | Yes — product owner, 2026-11-25 |"

mutate open/US-4.md case/US-4.md "| Negative |" "| Happy |"
expect "a gap in a not-ready map only warns" 0 "WARN: R1 has no Negative example" case/US-4.md
mutate ready/US-4.md case/US-4.md "(US-4) |" "(US-4); ideate/assumption-tests/2026-11-01-renew.md |"
expect "an assumption-tests path is not an assumption" 0 "0 check(s) failed" case/US-4.md
mutate ready/US-4.md case/US-4.md "A loan can be renewed once (BR-1)" "The renewal page loads within 2 seconds"
expect "an uncited quality target warns" 0 "WARN: R1 looks like a quality target" case/US-4.md
mutate ready/US-4.md case/US-4.md "| Ana renews the same loan again | Refused as already renewed |" "| the loan is renewed again | it is refused |"
expect "a vague example warns" 0 "WARN: R1.E2 may not be concrete" case/US-4.md
python3 - <<'PY'
t = open("ready/US-4.md").read()
block = t[t.index("### R1:"):t.index("## Questions")]
extra = "".join(block.replace("R1", "R%d" % n) for n in range(2, 7))
t = t.replace("## Questions", extra + "## Questions").replace("Rules: 1", "Rules: 6")
open("case/US-4.md", "w").write(t)
PY
expect "six rules warn about a split" 0 "WARN: 6 rules" case/US-4.md

smoke_test_summary
