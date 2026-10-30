#!/bin/bash
# Tests skills/uat-plan/scripts/check-uat-plan.py
# — a skill-owned script exercised directly with Markdown files (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/uat-plan/scripts/check-uat-plan.py"
T="check-uat-plan"

# 1. A clean plan passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: uat-plan
product: demo
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-10-29
summary: Demo Release 1 UAT over two Musts with an OAT smoke.
profile: standard
---

# UAT Plan — Demo

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | Musts | Users | Results | PO + customer |
| Operational acceptance (OAT) | yes | Restore | platform-engineer | Drill | PO |
| Contractual | no, because no contract | — | — | — | — |
| Regulatory | no, because no compliance scope | — | — | — | — |
| Alpha / beta | no, because no cohort | — | — | — | — |

## Scope Traceability
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk |
|---|---|---|---|---|
| US-1 Ask | AC-US-1 | a.feature | UAT-1a, UAT-1b | high |
| US-4 List | AC-US-4 | b.feature | UAT-4a | normal |

## Roles and Independence
- **Independence level (ISTQB):** business or user community

## Environment
Canary tenant t1.

## Entry Criteria
- [ ] Pass threshold and defect bar agreed by the accepting authority before execution

## Exit Criteria
- Every scenario Pass, Fail, Blocked or Not run
- Open defects: per the defect rule in acceptance-sign-off
- Residual risk written

## Schedule
Day 1 run · Day 2 re-test · Day 3 decision

## Exploratory Charters
- EX-1: Explore replies, with odd words, to discover misreads

## Completion Summary
- Residual risk: none beyond the above
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean plan passes" || _fail "$T: clean plan passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "wrong phase" 's/^phase: customer-validation/phase: quality/' "phase is 'quality'"
expect_error "missing summary" '/^summary:/d' "'summary' missing"
expect_error "bad profile" 's/^profile: standard/profile: huge/' "profile 'huge'"
expect_error "missing section" 's/^## Environment/## Where/' "'## Environment' missing"
expect_error "type row missing" '/^| Regulatory/d' "no row for acceptance type 'regulatory'"
expect_error "type cell not yes/no" 's/| Contractual | no, because no contract |/| Contractual | maybe |/' "'contractual' row's In scope cell"
expect_error "Must with no scenario" 's/| UAT-4a | normal |/| — | normal |/' "US-4 has no UAT scenario ID"
expect_error "no independence line" '/Independence level/d' "no 'Independence level' line"
expect_error "solo with no exception" 's/business or user community/none/' "no '## Exception: solo operator' section"
expect_error "yardstick not agreed first" 's/agreed by the accepting authority before execution/set/' "agreed before execution"
expect_error "no Blocked state" 's/Pass, Fail, Blocked or Not run/Pass, Fail or Not run/' "'Blocked' result state"
expect_error "restated High bar" 's/^- Open defects: per the defect rule in acceptance-sign-off/- Zero open Critical or High defects/' "restate a High-defect bar"
expect_error "no residual risk in exit" 's/^- Residual risk written/- Done/' "Exit Criteria do not mention residual risk"
expect_error "no re-test" 's/Day 2 re-test/Day 2 compile/' "no re-test step"
expect_error "no charter form" 's/^- EX-1: Explore replies, with odd words, to discover misreads/- EX-1: click around/' "no charter in the"

# 3. Warning: scenario IDs with a different root.
sed -e 's/| UAT-4a | normal |/| UAT-7a | normal |/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"US-4's scenario IDs do not share its root"* ]] && _pass "$T: warns on a mismatched ID root" || _fail "$T: warns on a mismatched ID root" "rc=$rc $out"

# 4. A solo plan with a full exception passes; capping it at conditional fails.
sed -e 's/business or user community/none/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/solo.md"
cat >> "$SCRATCH_DIR/solo.md" <<'EOF'

## Exception: solo operator
- Why no second party: no external users yet
- Independence in time: scenarios frozen on 2026-10-20
- Evidence per scenario: screenshots
- Borrowed session: one colleague, UAT-1a
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/solo.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: recorded solo exception passes" || _fail "$T: recorded solo exception passes" "rc=$rc $out"
sed -e 's/^- Borrowed session: one colleague, UAT-1a/- Borrowed session: none; outcome capped at conditional/' "$SCRATCH_DIR/solo.md" > "$SCRATCH_DIR/solo2.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/solo2.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"must not cap the outcome at conditional"* ]] && _pass "$T: solo cap at conditional rejected" || _fail "$T: solo cap at conditional rejected" "rc=$rc $out"
sed -e '/^- Evidence per scenario/d' "$SCRATCH_DIR/solo.md" > "$SCRATCH_DIR/solo3.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/solo3.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"missing its evidence line"* ]] && _pass "$T: solo exception without evidence caught" || _fail "$T: solo exception without evidence caught" "rc=$rc $out"

python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 5. The skill's own worked plans pass, with no warnings.
for ex in "$REPO_ROOT"/skills/uat-plan/examples/*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x[1] for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S) if x[1].startswith("---\nname:")]
open(sys.argv[2], "w").write(b[0] + "\n")
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
