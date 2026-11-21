#!/bin/bash
# Tests skills/architecture-evaluation/scripts/validate-architecture-evaluation.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples or template, so the
# test does not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/architecture-evaluation/scripts/validate-architecture-evaluation.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-architecture-evaluation: $label"
  else
    _fail "validate-architecture-evaluation: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
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
name: architecture-evaluation
product: stackwise
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
summary: The design meets its two top scenarios with one risk and one resolved trade-off.
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md]
self-check: true
---

# Architecture Evaluation for Stackwise

- **Profile:** standard
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days).

## Scenarios Evaluated

| Scenario | Rating (value, impact) | Response measure | Approaches that serve it |
|---|---|---|---|
| NFR-REL-01 | (H, H) | a restore within 1 hour | nightly backup, ADR-0002 |
| NFR-PERF-01 | (H, M) | a page in 2 s at the 95th percentile | read cache, ADR-0003 |

## Tactics Questionnaire

| Scenario | Tactic family | Question | Answer | Where in the design |
|---|---|---|---|---|
| NFR-REL-01 | recover from faults | is there a rollback or restore path? | partial | backup job in the platform |
| NFR-PERF-01 | manage resources | are copies of hot data kept? | yes | the read cache container |

## Risks

| ID | Scenario | Decision | Why it may fail | Action |
|---|---|---|---|---|
| R-1 | NFR-REL-01 | restores are never rehearsed | an untested restore may exceed 1 hour | add a restore drill; ADR not needed |

## Non-Risks

| ID | Scenario | Decision | Reason it is safe |
|---|---|---|---|
| N-1 | NFR-PERF-01 | a read cache in front of the database | the hit rate holds the page under 2 s in the sizing |

## Sensitivity Points

| ID | Property | Response it governs | Value or limit that matters |
|---|---|---|---|
| S-1 | cache time to live | page freshness | 60 seconds |

## Trade-off Points

| ID | Property | Raises | Lowers | Carried from | Resolution |
|---|---|---|---|---|---|
| T-1 | cache time to live | speed | freshness | TP-1 | ADR-0003 |

## Fitness Functions

| Characteristic | Rule that must stay true | Check | Where it runs | Owner |
|---|---|---|---|---|
| speed | the page stays under 2 s at the 95th percentile | a load test gate | the deployment pipeline | platform-engineer |

## Actions

- Add the restore drill; owner: platform-engineer.

## Open Questions

- Whether stale data for 60 seconds is acceptable; owner: product owner.
EOF

cat > lean-none.md <<'EOF'
---
name: architecture-evaluation
product: tinytool
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
summary: No scenario is rated high on architectural impact, so nothing needed a deeper check.
traces-to: [ideate/nfr-specification.md]
self-check: true
---

# Architecture Evaluation for Tinytool

- **Profile:** lean
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM.

## Scenarios Evaluated

No scenario is rated high on architectural impact in the handoff, so the design needs no deeper check.

## Open Questions

- None: nothing is open at lean.
EOF
sed -i 's/^- None: nothing is open at lean\./- None: no questions yet./' lean-none.md

expect "a complete standard record passes" 0 "0 check(s) failed" good.md
expect "a lean record with no high scenario passes" 0 "0 check(s) failed" lean-none.md
expect "missing file is a usage error" 2 "" nosuch.md
out="$("$VALIDATE" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -qF "Usage"; then
  _pass "validate-architecture-evaluation: no arguments is a usage error"
else
  _fail "validate-architecture-evaluation: no arguments is a usage error" "exit $code"
fi

mutate noselfflag.md "self-check: true" "self-check: false"
expect "frontmatter self-check false fails" 1 "frontmatter says self-check: true" noselfflag.md

mutate notindep.md "not independent, and not an ATAM" "thorough, and not an ATAM"
expect "a statement that omits not independent fails" 1 "not independent" notindep.md

mutate notatam.md "not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days)." "not independent."
expect "a statement that omits not an ATAM fails" 1 "not an ATAM" notatam.md

mutate claimatam.md "## Actions" "## Actions

We performed an ATAM with the team."
expect "claiming an ATAM was performed fails" 1 "ATAM is never claimed" claimatam.md

mutate claimindep.md "## Actions" "## Actions

This was an independent review of the design."
expect "claiming an independent review fails" 1 "no claim of an independent review" claimindep.md

mutate noid.md "| NFR-REL-01 | (H, H) | a restore within 1 hour |" "| restore time | (H, H) | a restore within 1 hour |"
expect "a scenario without an NFR id fails" 1 "carries an NFR id" noid.md

mutate nomeasure.md "| (H, H) | a restore within 1 hour |" "| (H, H) | ? |"
expect "a scenario without a response measure fails" 1 "a response measure is given" nomeasure.md

mutate badanswer.md "| recover from faults | is there a rollback or restore path? | partial |" "| recover from faults | is there a rollback or restore path? | maybe |"
expect "a questionnaire answer outside yes, partial, no fails" 1 "the answer is yes, partial or no" badanswer.md

mutate uncovered.md "| NFR-PERF-01 | manage resources | are copies of hot data kept? | yes | the read cache container |
" ""
python3 - <<'PY'
t = open("uncovered.md").read()
t = t.replace("| N-1 | NFR-PERF-01 |", "| N-1 | NFR-PERF-09 |")
open("uncovered.md", "w").write(t)
PY
expect "a scenario with no questionnaire row, risk or non-risk fails" 1 "has a questionnaire row, a risk or a non-risk" uncovered.md

mutate norisk.md "| R-1 | NFR-REL-01 | restores are never rehearsed | an untested restore may exceed 1 hour | add a restore drill; ADR not needed |" "| R-1 |  | restores are never rehearsed | an untested restore may exceed 1 hour |  |"
expect "a risk without a scenario and an action fails" 1 "names a scenario" norisk.md

mutate noreason.md "| the hit rate holds the page under 2 s in the sizing |" "|  |"
expect "a non-risk without a reason fails" 1 "states the reason it is safe" noreason.md

mutate nosensresp.md "| S-1 | cache time to live | page freshness | 60 seconds |" "| S-1 | cache time to live |  | 60 seconds |"
expect "a sensitivity point without the response it governs fails" 1 "names the response it governs" nosensresp.md

mutate samesides.md "| T-1 | cache time to live | speed | freshness | TP-1 | ADR-0003 |" "| T-1 | cache time to live | speed | speed | TP-1 | ADR-0003 |"
expect "a trade-off that raises and lowers the same attribute fails" 1 "a different attribute it lowers" samesides.md

mutate hidden.md "| TP-1 | ADR-0003 |" "| TP-1 | none |"
expect "a trade-off with no ADR, reason or user decision fails" 1 "resolved by an ADR, an accepted reason or a user decision" hidden.md

mutate accepted.md "| TP-1 | ADR-0003 |" "| TP-1 | accepted, no ADR: cheap to change and narrow |"
expect "a trade-off accepted with a reason passes" 0 "0 check(s) failed" accepted.md

mutate theme-lean.md "- **Profile:** standard" "- **Profile:** lean"
python3 - <<'PY'
t = open("theme-lean.md").read()
t = t.replace("## Fitness Functions", """## Risk Themes

| ID | Risks | Systemic weakness | Business driver threatened |
|---|---|---|---|
| RT-1 | R-1, R-2 | untested recovery | uptime |

## Fitness Functions""")
open("theme-lean.md", "w").write(t)
PY
expect "risk themes at lean fail" 1 "lean has no risk themes" theme-lean.md

python3 - <<'PY'
t = open("good.md").read()
t = t.replace("## Fitness Functions", """## Risk Themes

| ID | Risks | Systemic weakness | Business driver threatened |
|---|---|---|---|
| RT-1 | R-1 | untested recovery | uptime |

## Fitness Functions""")
open("onerisktheme.md", "w").write(t)
PY
expect "a theme of one risk fails" 1 "groups at least two risks" onerisktheme.md

mutate nocheckff.md "| a load test gate | the deployment pipeline |" "|  | the deployment pipeline |"
expect "a fitness function with no check fails" 1 "an automated check is named" nocheckff.md

mutate onetimeff.md "| a load test gate |" "| a one-time review at the gate |"
expect "a one-time review as a fitness function fails" 1 "not a one-time review" onetimeff.md

mutate noff.md "| speed | the page stays under 2 s at the 95th percentile | a load test gate | the deployment pipeline | platform-engineer |
" ""
expect "no fitness function at standard fails" 1 "fitness functions has at least one row" noff.md

mutate ent-noconfirm.md "- **Profile:** standard" "- **Profile:** enterprise"
expect "enterprise without a product owner confirmation fails" 1 "product owner's confirmation" ent-noconfirm.md

python3 - <<'PY'
t = open("ent-noconfirm.md").read()
t = t.replace("## Open Questions", "## Confirmation\n\n- **Product owner confirmation:** the product owner confirmed R-1 on 2026-11-20.\n\n## Open Questions")
t = t.replace("## Fitness Functions", "## Risk Themes\n\nNo risk themes: only one risk was found.\n\n## Fitness Functions")
open("ent-ok.md", "w").write(t)
PY
expect "an enterprise record with a confirmation passes" 0 "0 check(s) failed" ent-ok.md

mutate nobullet.md "- Whether stale data for 60 seconds is acceptable; owner: product owner." "nothing"
expect "no open question bullet fails" 1 "open questions has at least one bullet" nobullet.md

mutate code.md "## Actions" '```
code
```

## Actions'
expect "a code block warns" 0 "WARN: a code block" code.md

smoke_test_summary
