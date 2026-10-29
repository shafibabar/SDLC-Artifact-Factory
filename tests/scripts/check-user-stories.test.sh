#!/bin/bash
# Tests skills/user-story-writing/scripts/check-user-stories.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/user-story-writing/scripts/check-user-stories.py"
T="check-user-stories"

# 1. A clean standard backlog passes.
cat > "$SCRATCH_DIR/std.md" <<'EOF'
---
name: user-story-backlog
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-27
summary: Two stories for the confirm-request path.
profile: standard
---

Priorities in this document are provisional; moscow-prioritization finalises them.

## Backlog Summary

| ID | Story | Epic | Persona | UR / FR | Job story | Priority (provisional) |
|---|---|---|---|---|---|---|
| US-1 | Confirm request | EPIC-1 | P-3 | UR-1 | JS-1.1 | high |

## Stories

### EPIC-1: Front desk refills the slots of patients who aren't coming

#### US-1: Patient receives a confirm request
As a patient (P-3), I want to be asked whether I am still coming, so that I can say no while the slot can still be given away.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-2.1
- Rules: BR-1
- Priority (provisional): high
- Seed example: Mrs Okafor booked 16 days ahead and gets a request on Monday.
- Acceptance criteria: ideate/acceptance-criteria/US-1.md

#### US-2: Spike: what the SMS provider returns for a reply
- Question: what does the provider send us for an inbound reply?
- Output: a decision note.
- Unblocks: US-1 · Traces to: EPIC-1
- Priority (provisional): high

## Coverage

| Source | Stories |
|---|---|
| UR-1 | US-1 |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/std.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean standard backlog passes" || _fail "$T: clean standard backlog passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <file> <label> <sed-expression> <expected substring>
  sed -e "$3" "$SCRATCH_DIR/$1" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$4"* ]] && _pass "$T: $2" || _fail "$T: $2" "rc=$rc $out"
}
expect_error std.md "wrong name" 's/^name: user-story-backlog/name: user-stories/' "expected 'user-story-backlog'"
expect_error std.md "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error std.md "missing summary" '/^summary:/d' "missing 'summary'"
expect_error std.md "bad profile" 's/^profile: standard/profile: huge/' "is not lean, standard or enterprise"
expect_error std.md "MoSCoW priority rejected" '0,/^- Priority (provisional): high/s//- Priority (provisional): Must/' "uses MoSCoW"
expect_error std.md "unlabelled priority" '0,/^- Priority (provisional): high/s//- Priority: high/' "label the priority"
expect_error std.md "no card" 's/^As a patient (P-3), I want.*/Patients get a confirm request./' "no card"
expect_error std.md "as a user" 's/^As a patient (P-3),/As a user,/' "name a persona"
expect_error std.md "system as actor" 's/^As a patient (P-3),/As the system,/' "a system is the actor"
expect_error std.md "circular benefit" 's/so that I can say no.*/so that I can be asked whether I am still coming./' "repeats the want"
expect_error std.md "no traces" '/^- Traces to: EPIC-1 · UR-1/d' "no 'Traces to' line"
expect_error std.md "no job story" 's/ · J-1 → JS-1.1//' "cites no job story"
expect_error std.md "no epic" 's/^- Traces to: EPIC-1 · UR-1/- Traces to: UR-1/' "cites no epic"
expect_error std.md "no UR at standard" 's/ · UR-1 (FR-1.1)//' "no user or transition requirement"
expect_error std.md "no seed example" '/^- Seed example:/d' "no 'Seed example' line"
expect_error std.md "Given/When/Then on the card" 's/^- Rules: BR-1/- Given a booking 16 days ahead, when Monday comes, then a request is sent/' "Given/When/Then on the card"
expect_error std.md "size field" 's/^- Rules: BR-1/- Size: 3 story points/' "size, sprint or point field"
expect_error std.md "spike without output" '/^- Output: a decision note./d' "spike has no 'Output' line"
expect_error std.md "duplicate ID" 's/^#### US-2: Spike/#### US-1: Spike/' "duplicate story ID"
expect_error std.md "no coverage" 's/^## Coverage/## Mapping/' "no '## Coverage'"
expect_error std.md "no backlog summary" 's/^## Backlog Summary/## Table/' "no '## Backlog Summary'"
expect_error std.md "Must block not at standard" '$a\
\
## Must / Won'"'"'t-this-time — Release 1 (the walking skeleton)' "moscow-prioritization finalises priority"

# 3. Warning: an implementation word in the want.
sed -e 's/I want to be asked whether I am still coming/I want an endpoint that asks whether I am still coming/' "$SCRATCH_DIR/std.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"implementation word"* ]] && _pass "$T: warns on an implementation word" || _fail "$T: warns on an implementation word" "rc=$rc $out"

# 4. A clean lean backlog passes; lean-specific defects are caught.
cat > "$SCRATCH_DIR/lean.md" <<'EOF'
---
name: user-story-backlog
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-26
summary: A lean backlog with one story.
profile: lean
---

## Requirements Header (lean: the backlog is the functional requirements)

**Scope:** borrowing.

## Stories

### US-1: See whether a tool is in
As a member (P-1), I want to see whether a tool is in, so that I can plan my weekend project.
- Traces to: J-1 → JS-1.1 · KR-1.1
- Priority (provisional): high
- Seed example: the drill is out, due Saturday.

## Must / Won't-this-time — Release 1 (the walking skeleton)

Spine: find a tool.

### Must (the walking skeleton)
| Step | Story |
|---|---|
| Find a tool | US-1 |

### Won't this time
| Story | Why not now | Look again |
|---|---|---|
| none | — | — |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean lean backlog passes" || _fail "$T: clean lean backlog passes" "rc=$rc $out"
expect_error lean.md "lean needs the requirements header" 's/^## Requirements Header.*/## Notes/' "no '## Requirements Header'"
expect_error lean.md "lean needs the closing block" 's/^## Must \/ Won.t-this-time.*/## Release 1/' "no closing '## Must / Won't-this-time' block"
expect_error lean.md "closing block must be last" '$a\
\
## Intake Log (from the story map)' "must close the file"
expect_error lean.md "closing block needs a Won't table" 's/^### Won.t this time/### Later/' "no '### Won't this time' table"
expect_error lean.md "lean still needs a job story" 's/J-1 → JS-1.1 · //' "cites no job story"

python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 5. The skill's own worked backlogs (lean, standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/user-story-writing/examples/0[123]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: user-story-backlog")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
