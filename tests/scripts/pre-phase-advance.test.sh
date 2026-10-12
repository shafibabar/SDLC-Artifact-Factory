#!/bin/bash
# Contract for scripts/pre-phase-advance.sh. Since proposal 13 the gate reads
# product state from artifacts/<product>/_manifest.json: an agent may start
# only when its preceding phase is approved there (written by
# scripts/product-state.py). Manifests from before product state existed fall
# back to the old "preceding phase folder is non-empty" check.
# Deliberately no `set -e` — a failing case must not abort the remaining
# cases or the summary; smoke_test_script/summary carry the pass/fail state.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

payload() { printf '{"tool_input":{"subagent_type":"%s"},"cwd":"%s"}' "$1" "$2"; }
P="$SCRATCH_DIR/p"; mkdir -p "$P/artifacts/lunch"
manifest() {  # $1 = JSON for "phases" (or "" for a pre-proposal-13 manifest)
  if [[ -n "$1" ]]; then
    printf '{"product":"Lunch","product_slug":"lunch","current_phase":"ideate","phases":%s,"artifacts":[]}' "$1"
  else
    printf '{"product":"Lunch","product_slug":"lunch","artifacts":[]}'
  fi > "$P/artifacts/lunch/_manifest.json"
}

# 1. No product in this repo (e.g. the plugin's own repo) -> allow
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$REPO_ROOT")" "allow"

# 2. Preceding phase in progress -> deny, naming the phase
manifest '{"strategy":{"status":"in-progress"}}'
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "deny" "strategy phase hasn't been approved"

# 3. (#1247) the namespaced agent name is gated the same way
smoke_test_script "pre-phase-advance" "$(payload sdlc-artifact-factory:requirements-analyst "$P")" "deny" "strategy"

# 4. A file in the strategy folder is NOT enough any more: approval is what counts
mkdir -p "$P/artifacts/lunch/strategy" && touch "$P/artifacts/lunch/strategy/vision-statement.md"
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "deny" "product-state.py complete strategy"

# 5. Preceding phase approved -> allow (bare and namespaced)
manifest '{"strategy":{"status":"approved","approved_on":"2026-10-12"},"ideate":{"status":"in-progress"}}'
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "allow"
smoke_test_script "pre-phase-advance" "$(payload sdlc-artifact-factory:requirements-analyst "$P")" "allow"

# 6. Approved by override -> allow
manifest '{"strategy":{"status":"approved","approved_on":"2026-10-12","override":"user said go"}}'
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "allow"

# 7. Strategy has no prerequisite; another plugin's agent is not ours to gate
manifest '{"strategy":{"status":"in-progress"}}'
smoke_test_script "pre-phase-advance" "$(payload product-strategist "$P")" "allow"
smoke_test_script "pre-phase-advance" "$(payload other-plugin:requirements-analyst "$P")" "allow"
smoke_test_script "pre-phase-advance" "$(payload general-purpose "$P")" "allow"

# 8. Pre-proposal-13 manifest: falls back to the folder check
manifest ""
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "allow"
rm -rf "$P/artifacts/lunch/strategy"
smoke_test_script "pre-phase-advance" "$(payload requirements-analyst "$P")" "deny" "strategy"

# 9. Malformed JSON -> fail open (allow)
output="$(echo 'not json {{{' | "$REPO_ROOT/scripts/pre-phase-advance.sh" 2>&1)"
if [[ "$output" == *'"continue": true'* ]]; then
  echo "PASS: scripts/pre-phase-advance (case: malformed-input-fails-open)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: scripts/pre-phase-advance: malformed input did not fail open. Got: $output"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
