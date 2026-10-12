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

# Case 4 (#1252): the manifest the hook writes validates against the plugin's
# own schemas/sdlc-manifest.schema.json, using the artifact's frontmatter for
# version / producing_agent / traces_to. Before #1252 it failed with 39 errors.
P4="$SCRATCH_DIR/p4/artifacts/lunch-tracker"
mkdir -p "$P4/strategy" "$P4/design/decisions"
printf '%s\n' '---' 'name: vision-statement' 'version: 1.2.0' 'phase: strategy' \
  'owner: product-strategist' 'created: 2026-10-11' 'summary: Office staff order lunch in one minute.' \
  'traces_to: [the problem statement]' '---' '# Vision' > "$P4/strategy/vision-statement.md"
printf '%s\n' '---' 'name: adr-001-sqlite' 'version: 1.0.0' 'phase: design' \
  'owner: enterprise-architect' 'created: 2026-10-11' 'summary: Use SQLite.' 'traces_to: D002' '---' \
  > "$P4/design/decisions/ADR-001-sqlite.md"
printf '%s\n' '---' 'name: okrs' 'version: 1.0.0' 'phase: strategy' 'owner: product-strategist' \
  'created: 2026-10-11' 'summary: OKRs.' '---' > "$P4/strategy/okrs.md"
for f in strategy/vision-statement.md design/decisions/ADR-001-sqlite.md strategy/okrs.md; do
  echo '{"tool_input":{"file_path":"'"$P4/$f"'"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
done
if python3 -c "
import json, jsonschema
m = json.load(open('$P4/_manifest.json'))
schema = json.load(open('$REPO_ROOT/schemas/sdlc-manifest.schema.json'))
jsonschema.Draft202012Validator(schema).validate(m)
by = {a['type']: a for a in m['artifacts']}
assert by['vision-statement']['version'] == '1.2.0', by['vision-statement']
assert by['vision-statement']['producing_agent'] == 'product-strategist'
assert by['vision-statement']['traces_to'] == {'kind': 'requirement', 'ref': 'the problem statement'}
assert by['decision']['traces_to'] == {'kind': 'decision', 'ref': 'D002'}, by['decision']
assert 'traces_to' not in by['okrs'], 'a trace must never be invented'
"; then
  echo "PASS: $NAME (case: manifest-validates-against-schema)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: written manifest does not validate against sdlc-manifest.schema.json"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 5: an approval survives a later rewrite of the artifact; version follows the file.
python3 -c "
import json; p='$P4/_manifest.json'; m=json.load(open(p))
for a in m['artifacts']:
    if a['type'] == 'vision-statement': a['status'] = 'approved'
json.dump(m, open(p, 'w'), indent=2)"
sed -i 's/^version: 1.2.0$/version: 1.3.0/' "$P4/strategy/vision-statement.md"
echo '{"tool_input":{"file_path":"'"$P4/strategy/vision-statement.md"'"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
if python3 -c "
import json
m = json.load(open('$P4/_manifest.json'))
v = [a for a in m['artifacts'] if a['type'] == 'vision-statement'][0]
assert v['status'] == 'approved' and v['version'] == '1.3.0', v
assert len(m['artifacts']) == 3
"; then
  echo "PASS: $NAME (case: rewrite-keeps-approval-and-refreshes-version)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: rewrite reset the approval or kept a stale version"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 6: a manifest in the pre-#1252 minimal shape is upgraded in place, entries kept.
P6="$SCRATCH_DIR/p6/artifacts/old"
mkdir -p "$P6/strategy"
echo '{"_meta":{"product":"old","last_updated":"2026-10-01"},"artifacts":[{"id":"old-mission-001","type":"mission","phase":"strategy","path":"artifacts/old/strategy/mission.md","status":"draft","created":"2026-10-01","updated":"2026-10-01"}]}' > "$P6/_manifest.json"
echo '{"tool_input":{"file_path":"'"$P6/strategy/roadmap.md"'"},"cwd":"/x"}' | "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
if python3 -c "
import json, jsonschema
m = json.load(open('$P6/_manifest.json'))
jsonschema.Draft202012Validator(json.load(open('$REPO_ROOT/schemas/sdlc-manifest.schema.json'))).validate(m)
assert [a['id'] for a in m['artifacts']] == ['old-mission-001', 'old-roadmap-001'], m['artifacts']
"; then
  echo "PASS: $NAME (case: old-minimal-manifest-upgraded)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: pre-#1252 manifest was not upgraded to a valid one"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
