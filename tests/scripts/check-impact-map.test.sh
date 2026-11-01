#!/bin/bash
# Tests skills/impact-mapping/scripts/check-impact-map.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/impact-mapping/scripts/check-impact-map.py"
T="check-impact-map"

# 1. A clean standard map passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: impact-map
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-22
summary: No-shows 12% to 7% via confirm requests.
profile: standard
goal: no-show rate 12% → 7% by 2027-03-31
linked-kr: KR-2.1
linked-tree: ideate/opportunity-solution-tree.md
target-opportunity: OPP-3.1
selected-path: patient → confirms ahead → SOL-3
---

## Goal (WHY)

| Field | Value |
|---|---|
| Metric | No-show share |
| Meter | Diary status |
| Baseline | 12% |
| Target | 7% |
| Deadline | 2027-03-31 |

## Actors (WHO)

| Actor | Type | Why on the map | Source |
|---|---|---|---|
| Patient | Primary | Turns up | P-3 |
| Practitioner with a paper diary | Blocker | Keeps bookings off the system | snapshot |

## Map

### Actor: Patient — Primary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Confirms or cancels ahead instead of not turning up | OPP-3.1 "Patients forget" | SOL-3 confirm request (software) | selected | [usability] patients reply | Reply rate |
| | | Calendar file (software) | option | [desirability] they add it | Opens |

## Selected Path

| ID | Link | Assumption | Type | Evidence today | Test |
|---|---|---|---|---|---|
| PA-1 | SOL-3 → confirms | Patients reply | usability | none | T-1 |
| PA-2 | SOL-3 → confirms | Text reveals nothing about treatment | ethical | none | T-3 |

## Re-plan Trigger

If fewer than 70% reply after four weeks, try the calendar file.
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean map passes" || _fail "$T: clean map passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error "lean profile rejected" 's/^profile: standard/profile: lean/' "lean profile skips the impact map"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "goal field missing" '/^| Meter |/d' "no 'Meter' row"
expect_error "priority column rejected" 's/| Path | Assumption | Signal |/| Priority | Assumption | Signal |/' "Priority / MoSCoW column"
expect_error "MoSCoW value rejected" 's/| option | \[desirability\]/| Could | [desirability]/' "a MoSCoW priority"
expect_error "no selected row" 's/| selected |/| option |/' "no row marked 'selected'"
expect_error "selected row without signal" 's/| Reply rate |/| |/' "has no Signal"
expect_error "target opportunity not cited" 's/^target-opportunity: OPP-3.1/target-opportunity: OPP-4.1/' "no selected row cites the target opportunity"
expect_error "no blocker" 's/| Blocker |/| Secondary |/' "no Blocker actor"
expect_error "bad assumption type" 's/| usability | none | T-1 |/| risk | none | T-1 |/' "is not desirability"
expect_error "no re-plan trigger" 's/^## Re-plan Trigger/## Notes/' "no '## Re-plan Trigger'"

# 3. Warnings: no ethical assumption; feature-usage impact; MVP heading.
sed -e 's/| ethical | none | T-3 |/| viability | none | T-3 |/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"WARNING: Selected Path: no ethical assumption"* ]] && _pass "$T: warns on no ethical assumption" || _fail "$T: warns on no ethical assumption" "rc=$rc $out"
sed -e 's/| Confirms or cancels ahead instead of not turning up |/| Patient uses the reminders page |/' -e 's/^## Re-plan Trigger/## MVP Scope\n\n## Re-plan Trigger/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w2.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w2.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"reads as feature usage"* && "$out" == *"an 'MVP' heading"* ]] && _pass "$T: warns on feature usage and MVP heading" || _fail "$T: warns on feature usage and MVP heading" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked artifacts (standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/impact-mapping/examples/0[23]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: impact-map")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
