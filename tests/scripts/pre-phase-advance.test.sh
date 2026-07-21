#!/bin/bash
# Formalizes the manual test cases run during Chunk 20 development.
# Deliberately no `set -e` — a failing case must not abort the remaining
# cases or the summary; smoke_test_script/summary carry the pass/fail state.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# Case 1: real repo state, no product in progress -> allow
smoke_test_script "pre-phase-advance" \
  '{"tool_input":{"subagent_type":"requirements-analyst"},"cwd":"'"$REPO_ROOT"'"}' \
  "allow"

# Case 2: synthetic product in progress, missing prerequisite phase artifacts -> deny
mkdir -p "$SCRATCH_DIR/artifacts/testproduct"
python3 -c "
import json
d = json.load(open('$REPO_ROOT/sdlc-context.json'))
d['first_product']['status'] = 'In progress'
json.dump(d, open('$SCRATCH_DIR/sdlc-context.json','w'))
"
smoke_test_script "pre-phase-advance" \
  '{"tool_input":{"subagent_type":"requirements-analyst"},"cwd":"'"$SCRATCH_DIR"'"}' \
  "deny" "strategy"

# Case 3: same synthetic product, prerequisite now satisfied -> allow
mkdir -p "$SCRATCH_DIR/artifacts/testproduct/strategy"
touch "$SCRATCH_DIR/artifacts/testproduct/strategy/vision.md"
smoke_test_script "pre-phase-advance" \
  '{"tool_input":{"subagent_type":"requirements-analyst"},"cwd":"'"$SCRATCH_DIR"'"}' \
  "allow"

# Case 4: non-plugin agent type -> always allow
smoke_test_script "pre-phase-advance" \
  '{"tool_input":{"subagent_type":"general-purpose"},"cwd":"'"$SCRATCH_DIR"'"}' \
  "allow"

# Case 5: malformed JSON -> fail open (allow)
output="$(echo 'not json {{{' | "$REPO_ROOT/scripts/pre-phase-advance.sh" 2>&1)"
if [[ "$output" == *'"continue": true'* ]]; then
  echo "PASS: scripts/pre-phase-advance (case: malformed-input-fails-open)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: scripts/pre-phase-advance: malformed input did not fail open. Got: $output"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
