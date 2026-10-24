#!/bin/bash
# Tests skills/opportunity-solution-tree/scripts/check-opportunity-solution-tree.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/opportunity-solution-tree/scripts/check-opportunity-solution-tree.py"
T="check-opportunity-solution-tree"

# 1. A clean standard tree passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: opportunity-solution-tree
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-20
summary: No-shows 12% to 7%; target is forgotten appointments.
profile: standard
desired-outcome: no-show rate 12% → 7%
outcome-type: product outcome
evidence: ideate/interviews/snapshots/2026-10-02-c-1.md
target-opportunity: OPP-1.1
---

## Evidence

| ID | Kind |
|---|---|
| [2026-10-02-c-1] | snapshot |
| [FB-007] | feedback item |

## Opportunity Space

| ID | Parent | Opportunity (customer's voice) | Experience step | Evidence | Stories |
|---|---|---|---|---|---|
| OPP-1 | — | Attend | Attend | — | — |
| OPP-1.1 | OPP-1 | "Patients forget appointments booked weeks ahead" | Attend | [2026-10-02-c-1], [FB-007] | 2 |
| OPP-1.2 | OPP-1 | "Patients feel better and skip" | Attend | [assumption] | 0 |

**Target opportunity:** OPP-1.1. Most heard.

## Solutions for OPP-1.1

| ID | Solution | Kind | Pass | Carried forward? |
|---|---|---|---|---|
| SOL-1 | SMS reminder | software | 1 | yes |
| SOL-2 | Front desk phones | non-software | 2 | yes |
| SOL-3 | Reply to confirm | software | 1 | yes |

## Assumptions

| ID | Solution | Assumption | Type | Importance | Evidence today | Test first? |
|---|---|---|---|---|---|---|
| A-1 | SOL-1 | Patients read texts | desirability | high | none | yes |
| A-2 | SOL-1 | Text reveals no treatment | ethical | high | none | yes |

## Assumption Tests

| ID | Tests | Across | Test | Success criterion (set before running) | Runs it | Record |
|---|---|---|---|---|---|---|
| T-1 | A-1 | SOL-1, SOL-3 | Manual texts | At least 70% reply | the user | not yet run |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean tree passes" || _fail "$T: clean tree passes" "rc=$rc $out"

# 2. The defects the skill names: Strategy phase, a business outcome at the
#    root, missing target line, an orphan parent, a solution in disguise, an
#    uncited row, a citation not listed, one solution carried forward, an
#    invalid assumption type with no ethical row, and a criterion with no number.
cat > "$SCRATCH_DIR/bad.md" <<'EOF'
---
name: opportunity-solution-tree
version: 1.0.0
phase: strategy
owner: requirements-analyst
created: 2026-10-20
summary: Grow MRR.
profile: standard
desired-outcome: MRR $40k → $60k
outcome-type: business outcome
evidence: ideate/interviews/snapshots/2026-10-02-c-1.md
target-opportunity: OPP-9
---

## Evidence

| ID | Kind |
|---|---|
| [2026-10-02-c-1] | snapshot |

## Opportunity Space

| ID | Parent | Opportunity (customer's voice) | Experience step | Evidence | Stories |
|---|---|---|---|---|---|
| OPP-1 | — | Report | Report | — | — |
| OPP-1.1 | OPP-1 | "I wish there was a dashboard" | Report | [2026-10-02-c-1] | 1 |
| OPP-1.2 | OPP-4 | "I can't tell who owes me" | Report | DP-2 said so | 1 |
| OPP-1.3 | OPP-1 | "Late reminders" | Report | [2026-10-09-c-3] | 1 |

## Solutions for OPP-1.1

| ID | Solution | Kind | Pass | Carried forward? |
|---|---|---|---|---|
| SOL-1 | Dashboard | software | 1 | yes |
| SOL-2 | Email digest | software | 1 | parked |

## Assumptions

| ID | Solution | Assumption | Type | Importance | Evidence today | Test first? |
|---|---|---|---|---|---|---|
| A-1 | SOL-1 | They want it | value | high | none | yes |

## Assumption Tests

| ID | Tests | Across | Test | Success criterion (set before running) | Runs it | Record |
|---|---|---|---|---|---|---|
| T-1 | A-1 | SOL-1 | Show it | See if they like it | the user | not yet run |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
[[ $rc -eq 1 ]] && _pass "$T: defective tree exits 1" || _fail "$T: defective tree exits 1" "rc=$rc $out"
[[ "$out" == *"phase is 'strategy'"* ]] && _pass "$T: rejects phase strategy" || _fail "$T: rejects phase strategy" "$out"
[[ "$out" == *"outcome-type is a business outcome"* ]] && _pass "$T: rejects business outcome at root" || _fail "$T: rejects business outcome at root" "$out"
[[ "$out" == *"target-opportunity 'OPP-9' is not an opportunity"* ]] && _pass "$T: target must exist" || _fail "$T: target must exist" "$out"
[[ "$out" == *"no '**Target opportunity:**' line"* ]] && _pass "$T: target line required" || _fail "$T: target line required" "$out"
[[ "$out" == *"OPP-1.2: parent 'OPP-4' is not an opportunity"* ]] && _pass "$T: parents must exist" || _fail "$T: parents must exist" "$out"
[[ "$out" == *"WARNING: OPP-1.1: '\"I wish there was a dashboard\"' names a solution"* ]] && _pass "$T: warns on solution in disguise" || _fail "$T: warns on solution in disguise" "$out"
[[ "$out" == *"OPP-1.2: Evidence cites no snapshot or feedback item"* ]] && _pass "$T: opportunity must cite" || _fail "$T: opportunity must cite" "$out"
[[ "$out" == *"OPP-1.3: cites [2026-10-09-c-3] that is not listed"* ]] && _pass "$T: citation must be listed" || _fail "$T: citation must be listed" "$out"
[[ "$out" == *"1 solution(s) carried forward"* ]] && _pass "$T: several solutions" || _fail "$T: several solutions" "$out"
[[ "$out" == *"assumption type 'value'"* ]] && _pass "$T: five assumption types" || _fail "$T: five assumption types" "$out"
[[ "$out" == *"no ethical assumption"* ]] && _pass "$T: ethical assumption required" || _fail "$T: ethical assumption required" "$out"
[[ "$out" == *"T-1: success criterion 'See if they like it' has no number"* ]] && _pass "$T: numeric preset criterion" || _fail "$T: numeric preset criterion" "$out"

# 3. Traction metric refused; evidence: none with citations refused; a lean
#    list needs a Rank column; enterprise warns without a segment column.
sed -e 's/^outcome-type: .*/outcome-type: traction metric/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/tr.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/tr.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"outcome-type is a traction metric"* ]] && _pass "$T: rejects traction metric" || _fail "$T: rejects traction metric" "rc=$rc $out"
sed -e 's#^evidence: .*#evidence: none#' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/none.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/none.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"but frontmatter says 'evidence: none'"* ]] && _pass "$T: no invented evidence" || _fail "$T: no invented evidence" "rc=$rc $out"
sed -e 's/^profile: standard/profile: lean/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/lean.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"lean: the opportunity list has no Rank column"* ]] && _pass "$T: lean list is ranked" || _fail "$T: lean list is ranked" "rc=$rc $out"
sed -e 's/^profile: standard/profile: enterprise/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/ent.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ent.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"WARNING: enterprise: no Segment / tenant role column"* ]] && _pass "$T: enterprise warns on no segment" || _fail "$T: enterprise warns on no segment" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked artifacts (lean, standard, enterprise) pass.
for ex in "$REPO_ROOT"/skills/opportunity-solution-tree/examples/0[123]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: opportunity-solution-tree")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
