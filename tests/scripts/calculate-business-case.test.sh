#!/bin/bash
# Tests skills/pricing-and-packaging/scripts/calculate-business-case.py — a
# skill-owned script exercised directly with a JSON file argument (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CALC="$REPO_ROOT/skills/pricing-and-packaging/scripts/calculate-business-case.py"
T="calculate-business-case"

# 1. A known case: 1000 x 10% x (500 - 100) = 40,000 contribution; fixed 10,000 -> net 30,000.
cat > "$SCRATCH_DIR/ok.json" <<'EOF'
{"currency": "EUR", "fixed_cost": 10000,
 "segments": [{"name": "Team", "size": 1000, "adoption": 0.1, "price": 500, "cost_to_serve": 100}]}
EOF
out="$(python3 "$CALC" "$SCRATCH_DIR/ok.json")"; rc=$?
if [[ $rc -eq 0 && "$out" == *"**Net: 30,000**"* && "$out" == *"| Team | 1,000 | 10.0% | 100 | 500 | 50,000 | 100 | 40,000 |"* ]]; then
  _pass "$T: base case arithmetic"
else
  _fail "$T: base case arithmetic" "rc=$rc $out"
fi

# 2. Break-even adoption = fixed / contribution = 0.25x.
[[ "$out" == *"0.25x the base adoption"* ]] && _pass "$T: break-even adoption multiplier" \
  || _fail "$T: break-even adoption multiplier" "$out"

# 3. Sensitivity grid: price -20%, adoption -20% -> 80 x (400 - 100) - 10000 = 14,000.
if [[ "$out" == *"| -20% | 14,000 |"* && "$out" == *"Pessimistic corner (price -20%, adoption -20%): net 14,000."* ]]; then
  _pass "$T: pessimistic corner of the sensitivity grid"
else
  _fail "$T: pessimistic corner of the sensitivity grid" "$out"
fi

# 4. Price below cost to serve is warned about.
cat > "$SCRATCH_DIR/loss.json" <<'EOF'
{"segments": [{"name": "Free-ish", "size": 100, "adoption": 0.5, "price": 5, "cost_to_serve": 8}]}
EOF
out="$(python3 "$CALC" "$SCRATCH_DIR/loss.json")"; rc=$?
[[ $rc -eq 0 && "$out" == *"WARNING: Free-ish: price 5 is below cost to serve 8"* ]] \
  && _pass "$T: warns when price is below cost to serve" \
  || _fail "$T: warns when price is below cost to serve" "rc=$rc $out"

# 5. Invalid input exits 2: adoption above 1, missing segments, unreadable file.
echo '{"segments": [{"name": "X", "size": 10, "adoption": 1.5, "price": 1, "cost_to_serve": 0}]}' > "$SCRATCH_DIR/bad.json"
python3 "$CALC" "$SCRATCH_DIR/bad.json" >/dev/null 2>&1; r1=$?
echo '{"fixed_cost": 1}' > "$SCRATCH_DIR/empty.json"
python3 "$CALC" "$SCRATCH_DIR/empty.json" >/dev/null 2>&1; r2=$?
python3 "$CALC" "$SCRATCH_DIR/missing.json" >/dev/null 2>&1; r3=$?
[[ $r1 -eq 2 && $r2 -eq 2 && $r3 -eq 2 ]] && _pass "$T: invalid input exits 2" \
  || _fail "$T: invalid input exits 2" "rc=$r1/$r2/$r3"

smoke_test_summary
