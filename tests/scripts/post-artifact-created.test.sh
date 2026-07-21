#!/bin/bash
# post-artifact-created.sh always "continues" (never blocks) — the behavior
# worth testing is the manifest side effect, not an allow/deny decision, so
# this doesn't use the generic smoke_test_script harness function.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

NAME="post-artifact-created"

# Case 1: manifest created correctly, path derived from file_path itself,
# NOT from cwd (this is the exact bug found and fixed during Chunk 20).
mkdir -p "$SCRATCH_DIR/artifacts/testproduct/strategy"
output="$(echo '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/artifacts/testproduct/strategy/vision.md"},"cwd":"/somewhere/completely/different"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" 2>&1)"
manifest="$SCRATCH_DIR/artifacts/testproduct/_manifest.json"
if [[ -f "$manifest" ]] && python3 -c "
import json, sys
m = json.load(open('$manifest'))
a = m['artifacts'][0]
assert a['id'] == 'testproduct-vision-001', a['id']
assert a['type'] == 'vision', a['type']
assert a['phase'] == 'strategy', a['phase']
assert a['status'] == 'draft', a['status']
" 2>/dev/null; then
  echo "PASS: $NAME (case: manifest-created-from-file-path-not-cwd)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: manifest not created correctly. Script output: $output"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 2: two multi-instance artifacts of the SAME catalog type (two ADRs,
# different filenames, same "decisions/" subdirectory) must share one
# sequence counter and land at 001/002 — not each become their own "type"
# keyed by filename (the bug this test caught: type was derived from the
# filename stem, so "ADR-001-x.md" and "ADR-002-y.md" were two different
# types and both got sequence 001).
mkdir -p "$SCRATCH_DIR/artifacts/testproduct/design/decisions"
echo '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/artifacts/testproduct/design/decisions/ADR-001-outbox.md"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
echo '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/artifacts/testproduct/design/decisions/ADR-002-cqrs.md"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
if python3 -c "
import json
m = json.load(open('$manifest'))
adrs = sorted(a['id'] for a in m['artifacts'] if a['type'] == 'decision')
assert adrs == ['testproduct-decision-001', 'testproduct-decision-002'], adrs
" 2>/dev/null; then
  echo "PASS: $NAME (case: same-type-multi-instance-sequence-increments)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: sequence did not increment correctly for same-type multi-instance artifacts"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 2b: single-instance artifact type inference still uses filename stem
if python3 -c "
import json
m = json.load(open('$manifest'))
v = [a for a in m['artifacts'] if a['id'] == 'testproduct-vision-001']
assert len(v) == 1, v
" 2>/dev/null; then
  echo "PASS: $NAME (case: single-instance-type-still-uses-filename-stem)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: single-instance type inference regressed"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 3: non-artifact path -> no manifest written, no crash
rm -rf "$SCRATCH_DIR/artifacts2" && mkdir -p "$SCRATCH_DIR/artifacts2"
output3="$(echo '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/artifacts2/CLAUDE.md"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" 2>&1)"
if [[ "$output3" == *'"continue": true'* ]] && [[ ! -f "$SCRATCH_DIR/artifacts2/_manifest.json" ]]; then
  echo "PASS: $NAME (case: non-artifact-path-no-manifest)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: non-artifact path did not behave correctly. Output: $output3"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
