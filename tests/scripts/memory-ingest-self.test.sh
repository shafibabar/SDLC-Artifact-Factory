#!/bin/bash
# Contract for #1249: project-memory nodes under .sdlc-memory/tree/self/ —
# the decisions /sdlc-start writes and the open questions agents raise — are
# indexed, readable by self_status.py, and an explicitly named file that can't
# be indexed is reported loudly instead of "done: 0 file(s) indexed".
# Reproduces the dogfood failure (discovery/fresh-eyes/01-dogfood.md):
# D001 silently skipped, then /sdlc-status reporting "Open questions: None".
# No LLM call; no venv needed (the engine degrades to lexical matching).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

MEM="$REPO_ROOT/scripts/memory"
PRODUCT="$SCRATCH_DIR/product"
SELF="$PRODUCT/.sdlc-memory/tree/self"
mkdir -p "$SELF/decisions" "$SELF/open_questions"
git -C "$PRODUCT" init -q

_pass() { echo "PASS: memory-ingest-self ($1)"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: memory-ingest-self ($1)${2:+ — $2}"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
run_mem() { (cd "$PRODUCT" && SDLC_MEMORY_REPO_ROOT="$PRODUCT" bash "$MEM/run.sh" "$@"); }

# Plain markdown, as skills/memory-recall tells agents to write these.
cat > "$SELF/decisions/D001.md" <<'EOF'
# D001: Drop Redpanda, AGE and Kubernetes for a 20-person tool

**Date:** 2026-10-11

**Rationale:** A single Postgres-backed service covers the load.
EOF
cat > "$SELF/open_questions/Q001.md" <<'EOF'
# Q001

**Question:** Who places the combined order when the admin is away?

**Status:** open
EOF
cat > "$SELF/open_questions/Q002.md" <<'EOF'
# Q002

**Question:** Do we need per-person cost splitting at launch?

**Status:** resolved — yes, split evenly
EOF

# 1. Explicit ingest of a decision, exactly as commands/sdlc-start.md runs it.
out="$(run_mem "$MEM/ingest.py" .sdlc-memory/tree/self/decisions/D001.md 2>&1)"; rc=$?
if [[ $rc -eq 0 && "$out" == *"-> sdlc://self/decisions/D001"* && "$out" == *"done: 1 file(s) indexed"* ]]; then
  _pass "decision written by /sdlc-start is indexed"
else
  _fail "decision written by /sdlc-start is indexed" "rc=$rc out=$out"
fi

# 2. Open questions indexed; self_status sees open vs resolved.
run_mem "$MEM/ingest.py" .sdlc-memory/tree/self/open_questions/Q001.md .sdlc-memory/tree/self/open_questions/Q002.md >/dev/null 2>&1
oq="$(run_mem "$MEM/self_status.py" open-questions --only-open 2>&1)"
if [[ "$oq" == *"open_questions/Q001"* && "$oq" == *"Who places the combined order"* && "$oq" != *"Q002"* ]]; then
  _pass "self_status lists the open question and not the resolved one"
else
  _fail "self_status lists the open question and not the resolved one" "$oq"
fi

dec="$(run_mem "$MEM/self_status.py" decisions 2>&1)"
if [[ "$dec" == *"Drop Redpanda, AGE and Kubernetes"* ]]; then
  _pass "self_status decisions shows the decision text, not its ID heading"
else
  _fail "self_status decisions shows the decision text, not its ID heading" "$dec"
fi

# 3. The write hook path: post-artifact-created calls ingest on every Write, so a
#    decision written with the Write tool is now indexed with no manual step.
cat > "$SELF/decisions/D002.md" <<'EOF'
# D002: Keep chi for the HTTP layer
EOF
printf '%s' '{"tool_input":{"file_path":"'"$SELF/decisions/D002.md"'"},"cwd":"'"$PRODUCT"'"}' \
  | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/scripts/post-artifact-created.sh" >/dev/null 2>&1
dec="$(run_mem "$MEM/self_status.py" decisions --limit 5 2>&1)"
if [[ "$dec" == *"Keep chi for the HTTP layer"* ]]; then
  _pass "a decision written via the Write hook is auto-indexed"
else
  _fail "a decision written via the Write hook is auto-indexed" "$dec"
fi

# 4. An explicitly named file that can't be indexed fails loudly.
echo "notes" > "$PRODUCT/notes.md"
out="$(run_mem "$MEM/ingest.py" notes.md 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *"SKIPPED:"*"not an indexable location"* ]]; then
  _pass "unindexable explicit path exits non-zero with a SKIPPED message"
else
  _fail "unindexable explicit path exits non-zero with a SKIPPED message" "rc=$rc out=$out"
fi

# 5. Directory sidecars (.abstract.md) are never indexed as leaves.
out="$(run_mem "$MEM/ingest.py" --all 2>&1)"
if [[ "$out" != *".abstract"* && "$out" == *"sdlc://self/open_questions/Q002"* ]]; then
  _pass "--all reindexes self nodes and skips directory sidecars"
else
  _fail "--all reindexes self nodes and skips directory sidecars" "$out"
fi

smoke_test_summary
