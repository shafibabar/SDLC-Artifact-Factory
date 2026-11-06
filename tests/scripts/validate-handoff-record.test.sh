#!/bin/bash
# Tests skills/ddd-agent-handoff/scripts/validate-handoff-record.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/ddd-agent-handoff/scripts/validate-handoff-record.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-handoff-record: $1"
  else
    _fail "validate-handoff-record: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: handoff-record
product: ferrylog
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-02
summary: Sailings Aggregates handed to enterprise-architect; accepted after one flag was fixed.
from: domain-modeler
to: enterprise-architect
mode: hand-over
status: accepted
traces-to: [design/sailings/aggregates.md]
---

# Hand-over: domain-modeler → enterprise-architect (Design)

## Concerns handed over

| Concern | Artifact | Definition of Done met | Note |
|---|---|---|---|
| Aggregates for Sailings | design/sailings/aggregates.md | yes | — |

## Mode

- **Mode:** hand-over
- **Why:** hand-over: the default
- **Changes:** none

## Flags back

| # | Raised by | Artifact | What is wrong or missing, with evidence | Owner | Status |
|---|---|---|---|---|---|
| 1 | enterprise-architect | design/sailings/aggregates.md | vehicle deck capacity missing from Sailing | domain-modeler | fixed |

## Open questions

- none
EOF
expect "a complete accepted record passes" good.md 0 "INFO: 1 concern(s), 1 flag(s), 0 open"

sed 's/| fixed |$/| open |/' good.md > openflag.md
expect "accepted with an open flag fails" openflag.md 1 "an accepted record has no open flag"

sed 's/| yes | — |$/| no — capacity missing | — |/' good.md > dod.md
expect "accepted with an unmet Definition of Done fails" dod.md 1 "an accepted record has every Definition of Done met"

sed 's/| enterprise-architect | design\/sailings/| domain-modeler | design\/sailings/' good.md > selfflag.md
expect "a flag raised by its own owner fails" selfflag.md 1 "raised by someone other than the owner"

sed 's/| domain-modeler | fixed |$/| the architects | fixed |/' good.md > badowner.md
expect "a flag owner that is not an agent fails" badowner.md 1 "owner is an agent of this plugin"

sed 's/| fixed |$/| declined |/' good.md > decl.md
expect "a declined flag with no reason fails" decl.md 1 "a declined flag gives the reason"

sed 's/^to: enterprise-architect$/to: domain-modeler/' good.md > same.md
expect "from and to the same agent fails" same.md 1 "from and to differ"

sed 's/^owner: domain-modeler$/owner: enterprise-architect/' good.md > own.md
expect "owner other than the producer fails" own.md 1 "owner is the producing agent"

sed 's/^mode: hand-over$/mode: facilitating/' good.md > mode.md
expect "an unknown mode fails" mode.md 1 "mode is 'hand-over' or 'joint review'"

sed 's/^mode: hand-over$/mode: joint review/' good.md > jr.md
expect "joint review without a named reason fails" jr.md 1 "joint review names its reason"

sed 's/^status: accepted$/status: model-revision/' good.md > mr.md
expect "model-revision with no resumption section fails" mr.md 1 "resumption kind 'model found wrong'"

{ sed 's/^status: accepted$/status: model-revision/' good.md; printf '\n## Resumption\n\n- **Interrupted:** 2026-03-03 — implementing Sailing\n- **Kind:** model found wrong\n- **Next step:** domain-modeler revises the Sailing boundary; downstream artifacts to review: design/sailings/read-models.md\n'; } > mrok.md
expect "model-revision routed to the owner with downstream artifacts passes" mrok.md 0

{ cat good.md; printf '\n## Resumption\n\n- **Interrupted:** 2026-03-03 — implementing Sailing\n- **Kind:** model found wrong\n- **Next step:** backend-engineer carries on\n'; } > forward.md
expect "a model found wrong on an accepted record fails (not resumed forward)" forward.md 1 "sets status model-revision"

{ sed 's/^status: accepted$/status: paused/' good.md; printf '\n## Resumption\n\n- **Interrupted:** 2026-03-03 — session limit\n- **Kind:** operational pause\n- **Next step:** carry on\n'; } > pause.md
expect "a paused record whose next step names no agent fails" pause.md 1 "next step names who acts"

sed '/^| Aggregates for Sailings/d' good.md > noconcern.md
expect "a record with no concerns fails" noconcern.md 1 "has at least one concern handed over"

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-handoff-record: no argument exits 2" || _fail "validate-handoff-record: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-handoff-record: a missing file exits 2" || _fail "validate-handoff-record: a missing file exits 2" "exit $code"

smoke_test_summary
