#!/bin/bash
# Tests skills/acceptance-criteria/scripts/scaffold-criteria.sh — a
# skill-owned script exercised directly with CLI args, not smoke_test_script's
# stdin-JSON hook contract.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SKILL="$REPO_ROOT/skills/acceptance-criteria"
SCAFFOLD="$SKILL/scripts/scaffold-criteria.sh"
cd "$SCRATCH_DIR"

mkmap() { # id, readiness
  mkdir -p artifacts/acme/ideate/example-maps
  printf -- '---\nname: example-map\nstory-id: %s\nreadiness: %s\n---\n' "$1" "$2" > "artifacts/acme/ideate/example-maps/$1.md"
}
check() { if eval "$2"; then _pass "scaffold-criteria: $1"; else _fail "scaffold-criteria: $1" "${3:-condition false}"; fi; }

mkmap US-9 ready
OUT="$("$SCAFFOLD" acme US-9 "Classify a newly connected file" 2>&1)"; RC=$?
check "writes ideate/acceptance-criteria/US-n.md, the name the agent and backlog expect" \
  '[ "$RC" -eq 0 ] && [ "$OUT" = "artifacts/acme/ideate/acceptance-criteria/US-9.md" ] && [ -f "$OUT" ]' "rc $RC: $OUT"
F=artifacts/acme/ideate/acceptance-criteria/US-9.md
check "story id, product, title and date filled" \
  'grep -q "^story-id: US-9$" $F && grep -q "^product: acme$" $F && grep -q "^# Acceptance Criteria: US-9 Classify a newly connected file$" $F && grep -q "^created: $(date +%Y-%m-%d)$" $F'
check "map path filled, no EM- reference" \
  'grep -q "Example map: ideate/example-maps/US-9.md" $F && ! grep -q "EM-" $F'
check "criterion IDs are AC-US-9.1 to .3" \
  '[ "$(grep -oE "^### AC-[^:]+" $F | tr "\n" " ")" = "### AC-US-9.1 ### AC-US-9.2 ### AC-US-9.3 " ]' "$(grep "^### " $F)"
check "a fresh scaffold does not pass the validator" '! "$SKILL/scripts/validate-criteria.sh" $F >/dev/null 2>&1'

mkmap US-43 ready
OUT="$("$SCAFFOLD" acme 43 'Handle read/write & \1 conflicts' 2>&1)"
check "a bare number becomes US-n" '[ "$OUT" = "artifacts/acme/ideate/acceptance-criteria/US-43.md" ]' "$OUT"
check "special characters in the title survive" 'grep -qF "# Acceptance Criteria: US-43 Handle read/write & \1 conflicts" "$OUT"'

check "refuses to overwrite" '! "$SCAFFOLD" acme US-9 "Again" >/dev/null 2>&1'

ERR="$("$SCAFFOLD" acme US-44 "No map" 2>&1)"; RC=$?
check "refuses a story with no example map" \
  '[ "$RC" -eq 1 ] && echo "$ERR" | grep "example-maps/US-44.md" >/dev/null && [ ! -e artifacts/acme/ideate/acceptance-criteria/US-44.md ]' "rc $RC: $ERR"
mkmap US-45 not-ready
ERR="$("$SCAFFOLD" acme US-45 "Not ready" 2>&1)"; RC=$?
check "refuses a map that is not ready" \
  '[ "$RC" -eq 1 ] && echo "$ERR" | grep -i "not ready" >/dev/null && [ ! -e artifacts/acme/ideate/acceptance-criteria/US-45.md ]' "rc $RC: $ERR"

"$SCAFFOLD" acme US-9 >/dev/null 2>&1; RC=$?
check "missing title exits 2 with usage" '[ "$RC" -eq 2 ]' "rc $RC"
"$SCAFFOLD" ../x US-9 "T" >/dev/null 2>&1; RC=$?
check "rejects a product name with a path" '[ "$RC" -eq 2 ]' "rc $RC"
"$SCAFFOLD" acme EM-1 "T" >/dev/null 2>&1; RC=$?
check "rejects a story id that is not US-n" '[ "$RC" -eq 2 ]' "rc $RC"
check "documented usage matches the script" 'grep -qF "scaffold-criteria.sh <product> <story-id> <story-title>" "$SKILL/SKILL.md"'

smoke_test_summary
