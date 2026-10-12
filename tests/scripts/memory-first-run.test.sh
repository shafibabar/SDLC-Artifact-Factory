#!/bin/bash
# Contract for #1258: the memory engine's first run in a fresh product repo.
#   - SessionStart orientation is read-only: it creates nothing in a repo
#     that has no index yet.
#   - Whatever first creates .sdlc-memory/ writes the .gitignore entries in the
#     same step (once, never duplicated).
#   - The one-time dependency install is announced to the user exactly once,
#     and .sdlc-memory/.skip-install opts out of it.
#   - sdlc-context.json gets a readable abstract, not its raw first characters.
# No LLM call and no real pip install (a stub stands in for bootstrap.sh).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

MEM="$REPO_ROOT/scripts/memory"
_pass() { echo "PASS: memory-first-run ($1)"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: memory-first-run ($1)${2:+ — $2}"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# 1. SessionStart in a fresh repo creates nothing.
P1="$SCRATCH_DIR/p1"; mkdir -p "$P1"; git -C "$P1" init -q
out="$(echo '{"cwd":"'"$P1"'"}' | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/scripts/memory-session-orient.sh" 2>&1)"
if [[ "$out" == *'"continue": true'* && ! -e "$P1/.sdlc-memory" && ! -e "$P1/.gitignore" ]]; then
  _pass "session orientation in a fresh repo creates nothing"
else
  _fail "session orientation in a fresh repo creates nothing" "out=$out; $(ls -A "$P1")"
fi

# 2. The first write that creates .sdlc-memory/ also writes .gitignore, once.
P2="$SCRATCH_DIR/p2"; mkdir -p "$P2/artifacts/demo/strategy"; git -C "$P2" init -q
printf 'node_modules/\n' > "$P2/.gitignore"
printf '%s\n' '---' 'name: vision-statement' 'version: 1.0.0' 'phase: strategy' 'owner: product-strategist' \
  'created: 2026-10-12' 'summary: Demo vision.' '---' > "$P2/artifacts/demo/strategy/vision-statement.md"
for _ in 1 2; do
  (cd "$P2" && SDLC_MEMORY_REPO_ROOT="$P2" python3 "$MEM/ingest.py" artifacts/demo/strategy/vision-statement.md >/dev/null 2>&1)
done
markers="$(grep -c "added by SDLC-Artifact-Factory's memory engine" "$P2/.gitignore")"
if [[ -f "$P2/.sdlc-memory/index.db" && "$markers" == "1" ]] \
   && grep -qx 'node_modules/' "$P2/.gitignore" \
   && grep -qx '.sdlc-memory/index.db' "$P2/.gitignore" && grep -qx '.sdlc-memory/.venv/' "$P2/.gitignore"; then
  _pass ".gitignore entries written with the index, once, keeping existing lines"
else
  _fail ".gitignore entries written with the index, once, keeping existing lines" "$(cat "$P2/.gitignore")"
fi

# 3. The install is announced once: a systemMessage when bootstrap reports an
#    install, plain continue otherwise.
P3="$SCRATCH_DIR/p3"; mkdir -p "$P3"
STUB="$SCRATCH_DIR/stub-bootstrap.sh"
printf '#!/bin/bash\necho "sdlc-memory: installed 223M into $1/.sdlc-memory/.venv"\n' > "$STUB"
out="$(echo '{"cwd":"'"$P3"'"}' | SDLC_MEMORY_BOOTSTRAP="$STUB" bash "$REPO_ROOT/scripts/memory-bootstrap.sh" 2>&1)"
if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
m = d.get('systemMessage', '')
assert d.get('continue') is True
assert '223M' in m and '.skip-install' in m and 'rm -rf .sdlc-memory/.venv' in m, m
" "$out" 2>/dev/null; then
  _pass "a real install is announced with size, removal and opt-out"
else
  _fail "a real install is announced with size, removal and opt-out" "$out"
fi
printf '#!/bin/bash\nexit 0\n' > "$STUB"
out="$(echo '{"cwd":"'"$P3"'"}' | SDLC_MEMORY_BOOTSTRAP="$STUB" bash "$REPO_ROOT/scripts/memory-bootstrap.sh" 2>&1)"
if [[ "$out" == '{"continue": true}' ]]; then
  _pass "no message when nothing was installed"
else
  _fail "no message when nothing was installed" "$out"
fi

# 4. .skip-install: the real bootstrap returns at once and creates no venv.
P4="$SCRATCH_DIR/p4"; mkdir -p "$P4/.sdlc-memory"; touch "$P4/.sdlc-memory/.skip-install"
start=$(date +%s)
bash "$MEM/bootstrap.sh" "$P4" >/dev/null 2>&1
if [[ ! -e "$P4/.sdlc-memory/.venv" && $(( $(date +%s) - start )) -lt 5 ]]; then
  _pass ".skip-install opts out of the dependency install"
else
  _fail ".skip-install opts out of the dependency install"
fi

# 5. sdlc-context.json gets a readable abstract.
P5="$SCRATCH_DIR/p5"; mkdir -p "$P5"; git -C "$P5" init -q
cat > "$P5/sdlc-context.json" <<'JSON'
{"_meta": {"purpose": "Product context"}, "first_product": {"name": "Lunch Order Tracker", "status": "Strategy — complete", "problem_statement": "A 20-person office orders lunch together."}}
JSON
(cd "$P5" && SDLC_MEMORY_REPO_ROOT="$P5" python3 "$MEM/ingest.py" sdlc-context.json >/dev/null 2>&1)
abstract="$(python3 -c "
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
print(c.execute(\"SELECT abstract FROM contexts WHERE uri='sdlc://context' AND level=0\").fetchone()[0])
" "$P5/.sdlc-memory/index.db" 2>&1)"
if [[ "$abstract" == "Lunch Order Tracker — Strategy — complete" ]]; then
  _pass "sdlc-context.json abstract names the product and its status"
else
  _fail "sdlc-context.json abstract names the product and its status" "$abstract"
fi

smoke_test_summary
