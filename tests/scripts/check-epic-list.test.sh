#!/bin/bash
# Tests skills/epic-definition/scripts/check-epic-list.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/epic-definition/scripts/check-epic-list.py"
T="check-epic-list"

# 1. A clean standard epic list passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: epic-list
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-25
summary: One epic for the confirm-request path.
profile: standard
linked-kr: KR-2.1
---

Priorities in this document are provisional and are finalised by moscow-prioritization.

## Epics

### EPIC-1: Front desk refills the slots of patients who aren't coming

As a result of this epic, the front desk will be able to see who is still coming.

**Hypothesis:** If we send confirm requests, we believe patients will reply, shown by reply rate, moving KR-2.1.

**Traces to:** deliverable SOL-3 (selected path) · job J-1 → job story JS-1.1 · UR-1 · KR-2.1
**Bounded Context (candidate):** Booking

**Risks:** value — assumed (T-1) · usability — assumed (T-1 replies) · feasibility — low (CON-1) · viability — tested (owners agreed)

**Epic acceptance criteria:**
- [ ] Long-gap appointments get a confirm request. *Example: 60 of 100 get one.*
- [ ] Replies change the status. *Example: "C" confirms the 10:00.*
- [ ] The front desk sees who has not confirmed. *Example: 4 of 10 unanswered are listed.*

**Story titles:**
1. Patient receives a confirm request
2. Patient's reply confirms or cancels
3. Front desk sees who is unconfirmed

**Size:** S
**Priority (provisional):** high

## Coverage

| Source | Epic |
|---|---|
| SOL-3 | EPIC-1 |

## Not Epics

| Item | Why not an epic | Where it goes |
|---|---|---|
| SOL-2 phoning | Procedure | Front-desk procedure |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean epic list passes" || _fail "$T: clean epic list passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error "lean profile rejected" 's/^profile: standard/profile: lean/' "no epic list at lean"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "MoSCoW priority rejected" 's/^\*\*Priority (provisional):\*\* high/**Priority (provisional):** Must/' "uses MoSCoW"
expect_error "sprint sizing rejected" 's/^\*\*Size:\*\* S/**Size:** S (2 sprints)/' "sprints, weeks or points"
expect_error "size mismatch" 's/^\*\*Size:\*\* S/**Size:** L/' "size L but 3 story titles"
expect_error "too few stories" '/^3\. Front desk sees who is unconfirmed/d' "2 story title(s)"
expect_error "no outcome statement" 's/As a result of this epic, the/The/' "no outcome statement"
expect_error "no hypothesis" '/^\*\*Hypothesis:/d' "no Hypothesis"
expect_error "no job story" 's/ → job story JS-1.1//' "cites no job story"
expect_error "no UR" 's/ · UR-1//' "no user or transition requirement"
expect_error "no Bounded Context" '/^\*\*Bounded Context/d' "no Bounded Context line"
expect_error "no risk line" '/^\*\*Risks:/d' "no four-risk line"
expect_error "risk missing viability" 's/ · viability — tested (owners agreed)//' "does not cover viability"
expect_error "risk bad status" 's/feasibility — low/feasibility — fine/' "is not tested, assumed or low"
expect_error "Given/When/Then criterion" 's/^- \[ \] Replies change the status.*/- [ ] Given a reply C, When it arrives, Then the status is confirmed./' "Given/When/Then"
expect_error "criterion without example" 's/ \*Example: 60 of 100 get one.\*//' "without a concrete example"
expect_error "too few criteria" '/^- \[ \] Replies change the status/d' "2 epic acceptance criteria"
expect_error "no coverage" 's/^## Coverage/## Mapping/' "no '## Coverage'"
expect_error "no not-epics" 's/^## Not Epics/## Other/' "no '## Not Epics'"
expect_error "enterprise needs cross-context flags" 's/^profile: standard/profile: enterprise/' "Cross-Context Flags"

# 3. Warning: a component name in the title.
sed -e 's/^### EPIC-1: .*/### EPIC-1: Confirmation service/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"names a component or layer"* ]] && _pass "$T: warns on a component title" || _fail "$T: warns on a component title" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked epic lists (standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/epic-definition/examples/0[23]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: epic-list")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
