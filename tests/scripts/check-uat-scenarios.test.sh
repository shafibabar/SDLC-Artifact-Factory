#!/bin/bash
# Tests skills/uat-scenario/scripts/check-uat-scenarios.py
# — a skill-owned script exercised directly with Markdown files (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/uat-scenario/scripts/check-uat-scenarios.py"
T="check-uat-scenarios"

# 1. A clean scenarios file passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: uat-scenarios-US-7
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-11-09
summary: UAT scenarios proving US-7 invoice export on the partner canary tenants.
story: US-7
profile: standard
traces-to: AC-US-7.1, AC-US-7.2
plan: customer-validation/uat-plan.md
---

# UAT Scenarios: US-7 Export the month's invoices

### UAT-7a: Bookkeeper exports March's invoices

**Traces to:** AC-US-7.1
**Performed by:** bookkeeper

**Preconditions and test data** (seeded by requirements-analyst):
- INV-2041 €1,200.00 Paid, March 2026 — confirm by: it appears in Invoices, filter March

**Environment:** harbour-uat · eu-west · build 2026.11.4

**Context (Given):** March shows INV-2041.

**Steps (When):**
1. Open Exports.
2. Choose Invoices, March 2026, and Export.

**Expected Outcome (Then):**
- The file has one row, INV-2041, with Total 1,200.00.

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| 2026-11-10 | Ana (bookkeeper) | Fail: total shows 1200 | rec/1.mp4 | FB-14, High; workaround: edit the cell | — | — |
| 2026-11-12 | Ana (bookkeeper) | Pass | rec/2.mp4 | FB-14 closed | 2026-11-10 | FB-15 |
| 2026-11-13 | Ana (bookkeeper) | Blocked: tenant offline | — | — | — | — |
| [ ] | [ ] | [Pass / Fail / Blocked: reason / Not run] | [ ] | [ ] | [ ] | [ ] |

### UAT-7b: Bookkeeper checks a voided invoice stays out

**Traces to:** AC-US-7.2
**Performed by:** bookkeeper

**Preconditions and test data** (seeded by requirements-analyst):
- INV-2044 €50.00 Void, March 2026 — confirm by: Invoices shows it as Void

**Environment:** harbour-uat · eu-west · build 2026.11.4

**Context (Given):** March shows INV-2044 as Void.

**Steps (When):**
1. Export March's invoices.

**Expected Outcome (Then):**
- INV-2044 is not in the file.

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| 2026-11-10 | Ana (bookkeeper) | Not run | — | — | — | — |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s)"* ]] && _pass "$T: clean file passes" || _fail "$T: clean file passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "missing summary" '/^summary:/d' "'summary' missing"
expect_error "wrong phase" 's/^phase: customer-validation/phase: quality/' "phase is 'quality'"
expect_error "artifact key" 's/^name: uat-scenarios-US-7/artifact: uat-scenarios-US-7/' "use 'name:'"
expect_error "zero-padded ID with no letter" 's/^### UAT-7a:/### UAT-007:/' "UAT-007 is not UAT-<n><letter>"
expect_error "another story's root" 's/^### UAT-7b:/### UAT-8b:/' "does not share the story's number root"
expect_error "no trace" '0,/^\*\*Traces to:\*\* AC-US-7.1/s//**Traces to:** the export story/' "has no 'Traces to:'"
expect_error "trace to another story" 's/^\*\*Traces to:\*\* AC-US-7.2/**Traces to:** AC-US-9.1/' "traces to another story's criterion"
expect_error "HTTP call in steps" 's/^1. Open Exports./1. Call GET \/exports\/invoices?month=3./' "contains an HTTP call"
expect_error "field assignment in outcome" 's/^- INV-2044 is not in the file./- invoice_status = void is excluded./' "contains a field assignment"
expect_error "dotted field in an outcome note" 's/^- INV-2044 is not in the file./- INV-2044 is not in the file.   ← AC: invoices.status = void/' "contains a field assignment"
expect_error "SQL in steps" 's/^1. Export March.s invoices./1. SELECT * FROM invoices WHERE month = 3./' "contains SQL"
expect_error "backticked identifier" 's/^- The file has one row, INV-2041, with Total 1,200.00./- `total_gross` equals 1200./' "backticked identifier"
expect_error "no confirm by" 's/ — confirm by: it appears in Invoices, filter March//' "'confirm by'"
expect_error "no preconditions items" '/^- INV-2044 €50.00 Void/d' "UAT-7b has no Preconditions items"
expect_error "no environment" '0,/^\*\*Environment:\*\*/{/^\*\*Environment:\*\*/d}' "has no 'Environment:' line"
expect_error "result outside the four" 's/| Pass | rec\/2.mp4/| Passed with issues | rec\/2.mp4/' "is not Pass, Fail, Blocked or Not run"
expect_error "Blocked with no reason" 's/| Blocked: tenant offline |/| Blocked |/' "Blocked with no reason"
expect_error "Fail with no feedback ID" 's/| FB-14, High; workaround: edit the cell |/| workaround: edit the cell |/' "Fail with no feedback ID"
expect_error "Fail with no workaround" 's/| FB-14, High; workaround: edit the cell |/| FB-14, High |/' "Fail with no workaround"
expect_error "restated defect bar" 's/^\*\*Story:\*\*.*//; s/^# UAT Scenarios: US-7.*/&\n\nNo open High defects are allowed at sign-off./' "restates a defect bar"

python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 3. The skill's own worked scenarios pass. The examples show scenario blocks
# only, so a frontmatter block for their story is added before checking.
for ex in "$REPO_ROOT"/skills/uat-scenario/examples/*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"```markdown\n(.*?)\n```\n", t, re.S) if x.startswith("### UAT-")][0]
n = re.match(r"### UAT-(\d+)", b).group(1)
fm = (f"---\nname: uat-scenarios-US-{n}\nversion: 1.0.0\nphase: customer-validation\n"
      f"owner: requirements-analyst\ncreated: 2026-11-01\nsummary: Example.\nstory: US-{n}\n"
      f"traces-to: AC-US-{n}.1\n---\n\n")
open(sys.argv[2], "w").write(fm + b + "\n")
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
