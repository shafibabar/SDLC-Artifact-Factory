#!/bin/bash
# Tests skills/nfr-specification/scripts/check-nfr.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/nfr-specification/scripts/check-nfr.py"
T="check-nfr"

# 1. A clean standard NFR specification passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: nfr-specification
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-28
summary: Rated quality attributes for the reply path.
profile: standard
architecture-handoff: [NFR-REL-01, NFR-DEPLOY-01]
---

## Inputs Consumed

| Input | Says | Became |
|---|---|---|
| QA-1 | Reply latency | NFR-PERF-01 |

## Characteristics Considered

| Characteristic | Decision |
|---|---|
| Safety | Declined: no harm possible |

## Ranking

| Rank | NFR | Business value | Architectural impact | Why |
|---|---|---|---|---|
| 1 | NFR-REL-01 | H | H | contract |
| 2 | NFR-PERF-01 | H | M | KR |
| 3 | NFR-DEPLOY-01 | M | H | replies all day |

## Quality-Attribute Scenarios

| ID | Characteristic (sub) | Source | Stimulus | Environment | Affected part | Response | Response measure | Traces to | Verification |
|---|---|---|---|---|---|---|---|---|---|
| NFR-PERF-01 | Performance efficiency | Patients | Reply | 08:00 peak, 600/h | Reply handling | Releases slot | P95 ≤ 2 min (Must), ≤ 30 s (Plan) | QA-1 | Load test |
| NFR-REL-01 | Reliability | Zone | Fails | Clinic hours | Whole service | Fails over | RTO ≤ 30 min (Must), ≤ 5 min (Plan) | QA-2 | Failover drill |
| NFR-DEPLOY-01 | Deployability | Developer | Fix ready | Clinic hours | Reply service | Deployed, no manual step | Replies lost 0 (Must); rollback ≤ 10 min (Must), ≤ 3 min (Plan) | Product property | Release rehearsal |

## Obligations from Business Rules

| ID | Business rule | Measurable obligation on this system | Verification |
|---|---|---|---|
| NFR-OBL-01 | BR-3 | Templates hold clinic, date and time only | Template test |

## Candidate Trade-off Points

None found.

## Process Targets

None set.

## Architecture Handoff

| NFR | Rating (value, impact) | Trade-off points | Tactic families (pointers only) |
|---|---|---|---|
| NFR-REL-01 | (H, H) | — | Redundancy |
| NFR-DEPLOY-01 | (M, H) | — | Rollback |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean specification passes" || _fail "$T: clean specification passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "design phase rejected" 's/^phase: ideate/phase: design/' "phase is 'design'"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "unknown profile" 's/^profile: standard/profile: huge/' "is not lean, standard or enterprise"
expect_error "empty environment" 's/| Reply | 08:00 peak, 600\/h |/| Reply | — |/' "'Environment' is empty"
expect_error "no environment column" 's/| Environment |/| Notes |/' "no 'Environment' column"
expect_error "no Must" 's/P95 ≤ 2 min (Must)/P95 ≤ 2 min/' "has no Must"
expect_error "standard needs Plan" 's/, ≤ 30 s (Plan)//' "has no Plan"
expect_error "enterprise needs Stretch" 's/^profile: standard/profile: enterprise/' "has no Stretch"
expect_error "enterprise needs a utility tree" 's/^profile: standard/profile: enterprise/' "needs a '## Utility Tree'"
expect_error "deployability required" 's/NFR-DEPLOY-01/NFR-MAINT-01/g' "no deployability scenario"
expect_error "DORA rate as a scenario" 's/| Fix ready |/| Change failure rate under 15% |/' "is a process target"
expect_error "obligation without BR" 's/| NFR-OBL-01 | BR-3 |/| NFR-OBL-01 | residency |/' "cites no business rule"
expect_error "ASR missing from handoff" '/^| NFR-REL-01 | (H, H)/d' "NFR-REL-01: rated H on architectural impact but missing"
expect_error "no trade-off section" 's/^## Candidate Trade-off Points/## Notes/' "no '## Candidate Trade-off Points'"
expect_error "no process targets section" 's/^## Process Targets/## Delivery/' "no '## Process Targets'"
expect_error "no ranking" 's/^## Ranking/## Order/' "no '## Ranking'"

# 3. Lean accepts short form and Must only; warnings for averages and too many scenarios.
python3 - "$SCRATCH_DIR/ok.md" "$SCRATCH_DIR/lean.md" <<'PY'
import sys
t = open(sys.argv[1]).read().replace("profile: standard", "profile: lean")
t = t.replace(", ≤ 30 s (Plan)", "").replace(", ≤ 5 min (Plan)", "").replace(", ≤ 3 min (Plan)", "")
open(sys.argv[2], "w").write(t)
PY
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: lean needs Must only" || _fail "$T: lean needs Must only" "rc=$rc $out"
sed -e 's/P95 ≤ 2 min (Must)/average ≤ 2 min (Must)/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"use percentiles"* ]] && _pass "$T: warns on averages" || _fail "$T: warns on averages" "rc=$rc $out"
python3 - "$SCRATCH_DIR/lean.md" "$SCRATCH_DIR/w2.md" <<'PY'
import sys
t = open(sys.argv[1]).read()
row = "| NFR-PERF-01 | Performance efficiency | Patients | Reply | 08:00 peak, 600/h | Reply handling | Releases slot | P95 ≤ 2 min (Must) | QA-1 | Load test |"
extra = "\n".join(row.replace("NFR-PERF-01", f"NFR-PERF-{n:02d}") for n in range(2, 9))
open(sys.argv[2], "w").write(t.replace(row, row + "\n" + extra))
PY
out="$(python3 "$CHK" "$SCRATCH_DIR/w2.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"scenarios at lean"* ]] && _pass "$T: warns on too many lean scenarios" || _fail "$T: warns on too many lean scenarios" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked specifications (lean, standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/nfr-specification/examples/0[123]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: nfr-specification")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
