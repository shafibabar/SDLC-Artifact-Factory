#!/bin/bash
# Distinct from tests/scripts/*.test.sh, which invoke each script's LOGIC
# directly by piping stdin JSON at it. These tests prove hooks.json actually
# binds each script to a real PreToolUse/PostToolUse Write event when a real
# Claude Code session runs — the thing script-level tests cannot prove on
# their own. Manually verified during development: a write with no
# frontmatter is blocked by validate-artifact-structure, and a valid write
# silently triggers post-artifact-created to create a manifest the prompt
# never asked for.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

NAME="hooks-wiring"

# Case 1: PreToolUse wiring — a Write with no frontmatter block into
# artifacts/ must be BLOCKED by validate-artifact-structure.sh, and the file
# must not land on disk. Proves hooks.json's PreToolUse/Write binding fires.
# acceptEdits, not bypassPermissions: bypassPermissions maps to
# --dangerously-skip-permissions, which is refused when running as root
# (this sandbox does) — acceptEdits still auto-accepts writes non-interactively.
mkdir -p "$SCRATCH_DIR/artifacts/testproduct/strategy"
BAD_PATH="$SCRATCH_DIR/artifacts/testproduct/strategy/vision.md"
timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" --add-dir "$SCRATCH_DIR" \
  --permission-mode acceptEdits -p \
  "Use the Write tool to create a file at exactly this path: $BAD_PATH — with this exact content and nothing else: '# Vision\n\nNo frontmatter here.\n'. Do not do anything else, do not read any other files, just attempt this one write and then stop." \
  --output-format text >/dev/null 2>&1

if [[ ! -f "$BAD_PATH" ]]; then
  echo "PASS: $NAME (case: pretooluse-blocks-write-without-frontmatter)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: write without frontmatter was NOT blocked — PreToolUse hook is not wired"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 2: PostToolUse wiring — a valid Write into artifacts/ must succeed,
# AND a _manifest.json must appear that the prompt never asked for. Only
# post-artifact-created.sh, triggered by the real hooks.json binding, could
# have created it. Proves hooks.json's PostToolUse/Write binding fires.
GOOD_PATH="$SCRATCH_DIR/artifacts/testproduct2/strategy/vision.md"
mkdir -p "$SCRATCH_DIR/artifacts/testproduct2/strategy"
timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" --add-dir "$SCRATCH_DIR" \
  --permission-mode acceptEdits -p \
  "Use the Write tool to create a file at exactly this path: $GOOD_PATH — with this exact content and nothing else:

---
name: vision-statement
version: 1.0.0
phase: strategy
owner: product-strategist
created: 2026-07-20
summary: Hook wiring verification vision.
---

# Vision

Hook wiring verification content.

Do not do anything else, do not read any other files, just write this one file and then stop." \
  --output-format text >/dev/null 2>&1

MANIFEST="$SCRATCH_DIR/artifacts/testproduct2/_manifest.json"
if [[ -f "$GOOD_PATH" ]] && [[ -f "$MANIFEST" ]] && python3 -c "
import json
m = json.load(open('$MANIFEST'))
a = m['artifacts'][0]
assert a['id'] == 'testproduct2-vision-001', a['id']
" 2>/dev/null; then
  echo "PASS: $NAME (case: posttooluse-triggers-unrequested-manifest-write)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: valid write did not land and/or manifest was not auto-created — PostToolUse hook is not wired"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Case 3: the methodology-review agent hook (#1255). An agent hook leaves no
# file behind, so the proof is the debug log: on an artifact write it must
# (a) spawn, (b) load the methodology-review skill via the Skill tool — the
# plugin's files are outside the product repo, so a Read-based hook was
# silently denied and passed everything unchecked — and (c) return ok:false
# for a planted BDD defect (a scenario step that is an API call). A write
# outside artifacts/ must not spawn it at all (the handler's `if` rule).
DEFECT_PATH="$SCRATCH_DIR/artifacts/testproduct3/ideate/acceptance-criteria.md"
OTHER_PATH="$SCRATCH_DIR/notes.md"
DEBUG_LOG="$SCRATCH_DIR/methodology-hook.debug.txt"
mkdir -p "$SCRATCH_DIR/artifacts/testproduct3/ideate"
timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" --add-dir "$SCRATCH_DIR" \
  --permission-mode acceptEdits --debug-file "$DEBUG_LOG" -p \
  "Make exactly two Write tool calls and nothing else. First, create $OTHER_PATH containing just: scratch notes. Second, create $DEFECT_PATH with exactly this content:

---
name: acceptance-criteria
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-18
summary: Acceptance criteria for placing a lunch order.
---

# Acceptance Criteria

Story: US-001 As an employee I want to order lunch so I eat on time.

Scenario: Employee places an order
  When I call POST /api/v1/orders with parameter qty=3
  Then the API returns HTTP 201

Then stop. Do not fix anything a hook reports." \
  --output-format text >/dev/null 2>&1

REVIEW_SPAWNS=$(grep -c 'Processing agent hook with prompt: A product artifact was just written' "$DEBUG_LOG" 2>/dev/null)
if [[ -f "$DEFECT_PATH" && -f "$OTHER_PATH" && "${REVIEW_SPAWNS:-0}" -eq 1 ]] \
  && grep -q 'tool=Skill .*outcome=ok' "$DEBUG_LOG" \
  && grep -q 'Got structured output: {"ok":false,"reason":"Methodology defects in' "$DEBUG_LOG"; then
  echo "PASS: $NAME (case: methodology-agent-hook-loads-skill-and-flags-defect)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: $NAME: methodology hook — spawns=${REVIEW_SPAWNS:-0} (want 1, artifact write only), skill loaded=$(grep -c 'tool=Skill .*outcome=ok' "$DEBUG_LOG" 2>/dev/null), defect flagged=$(grep -c '"ok":false,"reason":"Methodology defects in' "$DEBUG_LOG" 2>/dev/null)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
