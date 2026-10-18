#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# Non-artifact path -> allow (not in scope), silent
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/CLAUDE.md","content":"outbox pattern"}}' "allow"

# Drifted terms under artifacts/, mixed case -> warn, never blocks
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/artifacts/p/s/v.md","content":"We use the outbox pattern and circuit breaker everywhere. Also OUTBOX PATTERN."}}' \
  "warn" "Transactional Outbox"

# Clean canonical terms -> allow
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/artifacts/p/s/v.md","content":"We use the Transactional Outbox and Circuit Breaker."}}' \
  "allow"

# --- Edit (#1288): the hook runs after the edit and checks the whole file on disk
T="$SCRATCH_DIR/artifacts/p/s/t.md"; mkdir -p "$(dirname "$T")"
printf 'Intro.\n\nWe retry with a circuit breaker.\n' > "$T"
smoke_test_script "terminology-drift-detector" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'","old_string":"Intro.","new_string":"Introduction."}}' \
  "warn" "Circuit Breaker"
printf 'We retry with a Circuit Breaker.\n' > "$T"
smoke_test_script "terminology-drift-detector" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'","old_string":"retry","new_string":"retry"}}' \
  "allow"

smoke_test_summary
