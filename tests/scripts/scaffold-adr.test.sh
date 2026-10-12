#!/bin/bash
# Tests skills/adr-authoring/scripts/scaffold-adr.sh — a skill-owned script,
# not a repo-root hook script, so it takes plain CLI args and is exercised
# directly rather than via smoke_test_script's stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/adr-authoring/scripts/scaffold-adr.sh"

cd "$SCRATCH_DIR"

# First ADR for a product with none yet -> resolves to 001
OUT1="$("$SCAFFOLD" acme use-transactional-outbox "Use Transactional Outbox" 2>&1)"
if [ "$OUT1" = "artifacts/acme/design/decisions/ADR-001-use-transactional-outbox.md" ] && [ -f "$OUT1" ]; then
  _pass "scaffold-adr: first ADR resolves to 001"
else
  _fail "scaffold-adr: first ADR resolves to 001" "got: $OUT1"
fi

if grep -q "^adr-id: ADR-001$" "$OUT1" && grep -q "^title: Use Transactional Outbox$" "$OUT1" && grep -q "^# ADR-001: Use Transactional Outbox$" "$OUT1"; then
  _pass "scaffold-adr: frontmatter and heading filled in correctly"
else
  _fail "scaffold-adr: frontmatter and heading filled in correctly" "placeholders not replaced as expected"
fi

if grep -q "^created: $(date +%Y-%m-%d)$" "$OUT1"; then
  _pass "scaffold-adr: created filled in with today's date"
else
  _fail "scaffold-adr: created filled in with today's date" "created placeholder not replaced"
fi

if grep -q "^name: adr-001-use-transactional-outbox$" "$OUT1"; then
  _pass "scaffold-adr: artifact name filled from number + slug"
else
  _fail "scaffold-adr: artifact name filled from number + slug" "got: $(grep '^name:' "$OUT1")"
fi

# REGRESSION: a scaffolded ADR must pass the plugin's own blocking artifact hook
# (scripts/validate-artifact-structure.sh) — before the Fresh-Eyes pilot the ADR
# frontmatter lacked name/version/phase/owner/created, so writing one with the
# Write tool was DENIED.
HOOK_OUT="$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'/p/'+sys.argv[1],'content':open(sys.argv[1]).read()}}))" "$OUT1" | "$REPO_ROOT/scripts/validate-artifact-structure.sh")"
if echo "$HOOK_OUT" | grep -q '"permissionDecision": "deny"'; then
  _fail "scaffold-adr: scaffolded ADR passes validate-artifact-structure" "$HOOK_OUT"
else
  _pass "scaffold-adr: scaffolded ADR passes validate-artifact-structure"
fi

if bash "$REPO_ROOT/skills/adr-authoring/scripts/scaffold-adr.sh" acme 'Bad/Slug' >/dev/null 2>&1; then
  _fail "scaffold-adr: a non-kebab slug is rejected" "exit 0 on 'Bad/Slug'"
else
  _pass "scaffold-adr: a non-kebab slug is rejected"
fi

if grep -q "deciders: \[Who made this decision\]" "$OUT1" && grep -q -- "- \[ADR-NNN — related or dependent decision\]" "$OUT1"; then
  _pass "scaffold-adr: fields the script doesn't know (deciders, Related ADRs) stay untouched"
else
  _fail "scaffold-adr: fields the script doesn't know (deciders, Related ADRs) stay untouched" "unrelated placeholder was unexpectedly modified"
fi

# Second ADR for the same product -> resolves to 002, no title given so
# the slug is auto-Title-Cased
OUT2="$("$SCAFFOLD" acme use-mediator-topology 2>&1)"
if [ "$OUT2" = "artifacts/acme/design/decisions/ADR-002-use-mediator-topology.md" ] && grep -q "^title: Use Mediator Topology$" "$OUT2"; then
  _pass "scaffold-adr: second ADR auto-increments to 002 and Title-Cases a missing title"
else
  _fail "scaffold-adr: second ADR auto-increments to 002 and Title-Cases a missing title" "got: $OUT2"
fi

# A title containing a slash (sed-special) must not corrupt the output
OUT3="$("$SCAFFOLD" acme use-postgres-slash-redis "Use Postgres/Redis for caching" 2>&1)"
if grep -q "^title: Use Postgres/Redis for caching$" "$OUT3"; then
  _pass "scaffold-adr: a title containing a slash is escaped correctly, not corrupted"
else
  _fail "scaffold-adr: a title containing a slash is escaped correctly, not corrupted" "got: $(grep '^title:' "$OUT3" 2>/dev/null || echo 'no title line found')"
fi

# Missing required args -> non-zero exit, usage message on stderr
if ! "$SCAFFOLD" only-one-arg >/dev/null 2>/dev/null; then
  _pass "scaffold-adr: missing slug argument exits non-zero"
else
  _fail "scaffold-adr: missing slug argument exits non-zero" "script exited 0 with only one argument"
fi

smoke_test_summary
