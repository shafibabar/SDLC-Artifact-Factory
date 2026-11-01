#!/bin/bash
# Tests skills/stakeholder-mapping/scripts/check-stakeholder-map.py — a
# skill-owned script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/stakeholder-mapping/scripts/check-stakeholder-map.py"
T="check-stakeholder-map"

# 1. A clean map passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
## 1. Delivery Stakeholders

| Stakeholder | Power | Interest | Quadrant | Engagement need |
|---|---|---|---|---|
| The product owner | High — approves | High — owns it | Manage Closely | — |
| Security reviewer | 4 — can block | 2 — busy | Keep Satisfied | Brief first |

| Decision | Responsible | Accountable | Agree (veto) | Consulted | Informed |
|---|---|---|---|---|---|
| Release gate | test-strategist agent | The product owner | Security reviewer | — | Team |

## 2. Customer Buying Committee

| Role | Must believe | Likely objection | Proof | Likely profile | Loses by staying put |
|---|---|---|---|---|---|
| CFO | Pays back in a year | Cost | Payback sheet | Skeptic — likely | Write-offs |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s)"* ]] && _pass "$T: clean map passes" || _fail "$T: clean map passes" "rc=$rc $out"

# 2. The defects the skill names: two As, an agent as A, high power / low
#    interest in Monitor, a 1-3 scale, and a newsletter for a committee role.
cat > "$SCRATCH_DIR/bad.md" <<'EOF'
## Delivery stakeholders

| Stakeholder | Power | Interest | Quadrant |
|---|---|---|---|
| CISO | 3 | 1 | Monitor |
| Product owner | 3 | 3 | Manage Closely |

| Decision | R | A | C | I |
|---|---|---|---|---|
| Data scopes | backend-engineer agent | The product owner and backend-engineer agent | Reviewer | Partners |
| Pricing | product-strategist agent | product-strategist agent | — | — |

## Buying Committee

| Role | Must believe | Engagement |
|---|---|---|
| Office manager | Approval first | Monthly newsletter |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
[[ $rc -eq 1 ]] && _pass "$T: defective map exits 1" || _fail "$T: defective map exits 1" "rc=$rc $out"
[[ "$out" == *"1-3 score"* ]] && _pass "$T: rejects a 1-3 scale" || _fail "$T: rejects a 1-3 scale" "$out"
[[ "$out" == *"'CISO': quadrant 'Monitor' but power/interest give 'Keep Satisfied'"* ]] \
  && _pass "$T: high power / low interest must be Keep Satisfied" || _fail "$T: high power / low interest must be Keep Satisfied" "$out"
[[ "$out" == *"'Data scopes': more than one Accountable"* ]] && _pass "$T: two Accountables" || _fail "$T: two Accountables" "$out"
[[ "$out" == *"'Pricing': Accountable 'product-strategist agent' is not a person"* ]] \
  && _pass "$T: agent as Accountable" || _fail "$T: agent as Accountable" "$out"
[[ "$out" == *"mentions 'newsletter'"* ]] && _pass "$T: newsletter to a committee role" || _fail "$T: newsletter to a committee role" "$out"

# 3. Letter-matrix RACI: two As in a row, and an A held by an agent column.
cat > "$SCRATCH_DIR/matrix.md" <<'EOF'
## Delivery Stakeholders

| Decision | The product owner | backend-engineer agent | Design partners |
|---|---|---|---|
| Release | A | A | I |
| Schema | C | A | I |

## Buying Committee

None: consumer purchase, the user buys.
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/matrix.md")"; rc=$?
if [[ $rc -eq 1 && "$out" == *"'Release': 2 Accountable entries"* && "$out" == *"'Schema': Accountable 'backend-engineer agent' is not a person"* ]]; then
  _pass "$T: letter-matrix RACI checked"
else
  _fail "$T: letter-matrix RACI checked" "rc=$rc $out"
fi

# 4. A map with no committee section, and unreadable input.
printf '## Delivery Stakeholders\n\ntext\n' > "$SCRATCH_DIR/half.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/half.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"no 'Buying Committee' section"* ]] && _pass "$T: missing committee section" || _fail "$T: missing committee section" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

smoke_test_summary
