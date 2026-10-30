#!/bin/bash
# Tests skills/requirements-analysis/scripts/check-frd.py
# — a skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/requirements-analysis/scripts/check-frd.py"
T="check-frd"

# 1. A clean standard FRD passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: functional-requirements-document
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-24
summary: Requirements for the confirm-request path.
profile: standard
linked-kr: KR-2.1
linked-impact-map: ideate/impact-map.md
linked-jtbd: ideate/jtbd-analysis.md
---

Priorities in this document are provisional and are finalised by moscow-prioritization.

## User and Functional Requirements

### UR-1: The front desk must be able to see who is still coming

- **Traces to:** deliverable SOL-3 (selected path) · job J-1 "keep the diary full" → job story JS-1.1 · KR-2.1
- **Rationale:** refill slots in time.

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) |
|---|---|---|---|---|---|
| FR-1.1 | The system must send a confirm request for every appointment booked 14+ days ahead | For 100 seeded appointments, exactly 60 requests are queued | Acceptance test | BR-1 | high |

## Business Rules

| ID | Rule | Kind | Source | Cited by |
|---|---|---|---|---|
| BR-1 | Confirm 72 h before | computation | map | FR-1.1 |

## Transition Requirements

None, because there is no current tool.

## Quality-Attribute Hand-off (to `nfr-specification`)

| ID | Quality concern | Constrains | Why it matters here |
|---|---|---|---|
| QA-1 | Reply latency | FR-1.1 | refill |

## Assumption Log

| ID | Assumption | Requirements that depend on it | Impact if false | How it will be confirmed |
|---|---|---|---|---|
| ASM-1 | Patients reply | FR-1.1 | — | T-1 |

## TBD List

None.

## Waiting Room

| Item | Reason deferred | Would return if |
|---|---|---|
| Calendar file | Option on the map | Re-plan |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean FRD passes" || _fail "$T: clean FRD passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error "lean profile rejected" 's/^profile: standard/profile: lean/' "lean profile has no FRD"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "missing linked-jtbd" '/^linked-jtbd:/d' "missing 'linked-jtbd'"
expect_error "no job story" 's/ → job story JS-1.1//' "no job story"
expect_error "no job statement" 's/job J-1 "keep the diary full"/job "keep the diary full"/' "no job statement"
expect_error "no deliverable" 's/deliverable SOL-3 (selected path) · //' "no selected-path deliverable"
expect_error "MoSCoW priority rejected" 's/| BR-1 | high |/| BR-1 | Must |/' "is a MoSCoW label"
expect_error "bare test type as fit criterion" 's/| For 100 seeded appointments, exactly 60 requests are queued |/| Integration test |/' "bare test type"
expect_error "pending fit criterion rejected" 's/| For 100 seeded appointments, exactly 60 requests are queued |/| Pending TBD-3 |/' "pending or a bare test type"
expect_error "no fit criterion column" 's/| Fit criterion |/| Notes |/' "no Fit criterion column"
expect_error "no transition section" 's/^## Transition Requirements/## Other/' "no '## Transition Requirements'"
expect_error "no waiting room" 's/^## Waiting Room/## Later/' "no '## Waiting Room'"
expect_error "no UR headings" 's/^### UR-1:/### Group 1:/' "no '### UR-n'"

# expect_error with two sed expressions needs its own call.
sed -e 's/^linked-impact-map: .*/linked-impact-map: none/' -e 's/ · KR-2.1//' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"must trace to a Key Result"* ]] && _pass "$T: no map needs a KR (two edits)" || _fail "$T: no map needs a KR (two edits)" "rc=$rc $out"
sed -e 's/^linked-impact-map: .*/linked-impact-map: none (standard, map not produced)/' -e 's/deliverable SOL-3 (selected path) · //' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/nomap.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/nomap.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: no map at standard traces to the KR" || _fail "$T: no map at standard traces to the KR" "rc=$rc $out"

# 3. Warnings: ambiguous word; NFR number in an FR; simulated interviews.
sed -e 's/exactly 60 requests are queued/requests are queued quickly within 30 seconds/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"ambiguous word 'quickly'"* && "$out" == *"hand it to nfr-specification"* ]] && _pass "$T: warns on ambiguity and NFR numbers" || _fail "$T: warns on ambiguity and NFR numbers" "rc=$rc $out"
sed -e 's/^None, because there is no current tool./Simulated stakeholder interview with finance./' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w2.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w2.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"'simulated' found"* ]] && _pass "$T: warns on simulated interviews" || _fail "$T: warns on simulated interviews" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked FRDs (standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/requirements-analysis/examples/0[23]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: functional-requirements-document")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
