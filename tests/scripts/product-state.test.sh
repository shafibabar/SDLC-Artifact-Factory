#!/bin/bash
# Contract for scripts/product-state.py (proposal 13, #1251/#1253): a product's
# phase and approvals live in its manifest, written only after the user
# approves, and a phase completes only when its required artifacts are
# approved. Artifacts are written through the real post-artifact-created hook,
# so the hook and the script are tested together. No LLM call.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

PS="$REPO_ROOT/scripts/product-state.py"
P="$SCRATCH_DIR/product"; mkdir -p "$P"; git -C "$P" init -q
_pass() { echo "PASS: product-state ($1)"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: product-state ($1)${2:+ — $2}"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
ps() { (cd "$P" && SDLC_PRODUCT_ROOT="$P" python3 "$PS" "$@"); }
valid() {
  python3 -c "
import json, jsonschema, sys
jsonschema.Draft202012Validator(json.load(open('$REPO_ROOT/schemas/sdlc-manifest.schema.json'))).validate(json.load(open(sys.argv[1])))
" "$P/artifacts/lunch/_manifest.json" 2>&1
}
write() {  # write an artifact with frontmatter, through the real hook
  local rel="$1"; mkdir -p "$(dirname "$P/artifacts/lunch/$rel")"
  printf '%s\n' '---' "name: $(basename "$rel" .md)" 'version: 1.0.0' "phase: ${rel%%/*}" \
    'owner: product-strategist' 'created: 2026-10-12' 'summary: Test artifact.' '---' > "$P/artifacts/lunch/$rel"
  echo '{"tool_input":{"file_path":"'"$P/artifacts/lunch/$rel"'"},"cwd":"'"$P"'"}' \
    | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
}

# 1. status before anything exists
out="$(ps status)"
[[ "$out" == *'"product": null'* ]] && _pass "status with no product says so" || _fail "status with no product says so" "$out"

# 2. init creates a schema-valid manifest in the strategy phase
out="$(ps init lunch --name "Lunch Order Tracker" --problem "A 20-person office orders lunch together.")"; rc=$?
if [[ $rc -eq 0 && "$out" == *'"current_phase": "strategy"'* ]] && [[ -z "$(valid)" ]]; then
  _pass "init creates a valid manifest in strategy"
else
  _fail "init creates a valid manifest in strategy" "rc=$rc $out $(valid)"
fi

# 3. a second product is refused
ps init other --name "Other" >/dev/null 2>&1; rc=$?
[[ $rc -eq 1 ]] && _pass "a second init is refused" || _fail "a second init is refused" "rc=$rc"

# 4. approving something never written is refused
out="$(ps approve strategy/vision-statement.md 2>&1)"; rc=$?
[[ $rc -eq 1 && "$out" == *"unknown"* ]] && _pass "approving an unwritten artifact is refused" || _fail "approving an unwritten artifact is refused" "rc=$rc $out"

# 5. completing with work missing is refused and names what's missing
write strategy/vision-statement.md
out="$(ps complete strategy 2>&1)"; rc=$?
if [[ $rc -eq 1 && "$out" == *'"unapproved"'* && "$out" == *"vision-statement"* && "$out" == *'"missing"'* && "$out" == *"mission-statement"* ]]; then
  _pass "complete refuses and lists missing and unapproved artifacts"
else
  _fail "complete refuses and lists missing and unapproved artifacts" "rc=$rc $out"
fi

# 6. the hook keeps product state when it rewrites the manifest
cur="$(python3 -c "import json;print(json.load(open('$P/artifacts/lunch/_manifest.json'))['current_phase'])")"
[[ "$cur" == "strategy" && -z "$(valid)" ]] && _pass "hook rewrite keeps current_phase and stays valid" || _fail "hook rewrite keeps current_phase and stays valid" "$cur $(valid)"

# 7. write and approve the full Strategy set (alternate filenames accepted), then complete
for f in mission-statement stakeholder-map competitive-analysis lean-canvas positioning-gtm-strategy roadmap okrs; do
  write "strategy/$f.md"
done
out="$(ps approve strategy/vision-statement.md strategy/mission-statement.md strategy/stakeholder-map.md \
  strategy/competitive-analysis.md strategy/lean-canvas.md strategy/positioning-gtm-strategy.md strategy/roadmap.md strategy/okrs.md)"; rc=$?
[[ $rc -eq 0 ]] && _pass "approve records several artifacts" || _fail "approve records several artifacts" "$out"
out="$(ps complete strategy)"; rc=$?
if [[ $rc -eq 0 && "$out" == *'"current_phase": "ideate"'* ]] && [[ -z "$(valid)" ]]; then
  _pass "complete approves the phase and advances to ideate"
else
  _fail "complete approves the phase and advances to ideate" "rc=$rc $out $(valid)"
fi

# 8. an approval survives the artifact being rewritten
write strategy/okrs.md
st="$(python3 -c "
import json; m=json.load(open('$P/artifacts/lunch/_manifest.json'))
print([a['status'] for a in m['artifacts'] if a['path'].endswith('okrs.md')][0])")"
[[ "$st" == "approved" ]] && _pass "rewriting an approved artifact keeps its approval" || _fail "rewriting an approved artifact keeps its approval" "$st"

# 9. override approves an incomplete phase and records why
out="$(ps complete ideate --override "User chose to start design from the interview notes")"; rc=$?
ov="$(python3 -c "import json;print(json.load(open('$P/artifacts/lunch/_manifest.json'))['phases']['ideate'].get('override',''))")"
[[ $rc -eq 0 && "$ov" == "User chose"* && -z "$(valid)" ]] && _pass "override completes the phase and records the reason" || _fail "override completes the phase and records the reason" "rc=$rc $ov"

# 10. status reports the phase and what the current phase still needs
out="$(ps status)"
if [[ "$out" == *'"current_phase": "design"'* && "$out" == *'"current_phase_check"'* && "$out" == *"context-map"* ]]; then
  _pass "status reports the current phase and what it still needs"
else
  _fail "status reports the current phase and what it still needs" "$out"
fi

# 11. a code phase with no required documents completes on the user's approval alone
python3 - "$P/artifacts/lunch/_manifest.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p))
m["current_phase"] = "implement"; m["phases"]["design"] = {"status": "approved", "approved_on": "2026-10-12"}
json.dump(m, open(p, "w"), indent=2)
PY
out="$(ps complete implement)"; rc=$?
[[ $rc -eq 0 && "$out" == *'"current_phase": "data"'* ]] && _pass "a code phase completes on the user's approval" || _fail "a code phase completes on the user's approval" "rc=$rc $out"

smoke_test_summary
