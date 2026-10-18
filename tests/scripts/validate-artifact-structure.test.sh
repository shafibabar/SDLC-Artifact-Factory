#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# Non-artifact path always allowed regardless of content
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/CLAUDE.md","content":"no frontmatter at all"}}' \
  "allow"

# Missing required frontmatter fields under artifacts/ -> deny
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"---\nname: v\n---\n"}}' \
  "deny" "missing required field"

# The five pre-memory-engine fields without summary -> deny, naming summary
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"---\nname: v\nversion: 1.0.0\nphase: strategy\nowner: x\ncreated: 2026-07-20\n---\n"}}' \
  "deny" "summary"

# Complete frontmatter (all six fields) -> allow
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"---\nname: v\nversion: 1.0.0\nphase: strategy\nowner: x\ncreated: 2026-07-20\nsummary: One-line abstract.\n---\n"}}' \
  "allow"

# Missing a required field even when summary is present -> deny, naming the field
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"---\nname: v\nversion: 1.0.0\nphase: strategy\ncreated: 2026-07-20\nsummary: x\n---\n"}}' \
  "deny" "owner"

# No frontmatter block at all under artifacts/ -> deny
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"# No frontmatter here"}}' \
  "deny" "no frontmatter"

# --- Edit (#1288): an Edit carries old_string/new_string, so the check works
# out the post-edit text from the file on disk.
A="$SCRATCH_DIR/artifacts/p/strategy/v.md"; mkdir -p "$(dirname "$A")"
printf -- '---\nname: v\nversion: 1.0.0\nphase: strategy\nowner: x\ncreated: 2026-07-20\nsummary: One-line abstract.\n---\n\n# Vision\n' > "$A"

# Edit that removes a required field -> deny, naming it
smoke_test_script "validate-artifact-structure" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$A"'","old_string":"summary: One-line abstract.\n","new_string":""}}' \
  "deny" "summary"

# Edit that strips the whole frontmatter block -> deny
smoke_test_script "validate-artifact-structure" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$A"'","old_string":"---\nname: v\nversion: 1.0.0\nphase: strategy\nowner: x\ncreated: 2026-07-20\nsummary: One-line abstract.\n---\n\n","new_string":""}}' \
  "deny" "no frontmatter"

# Edit to the body that keeps the frontmatter -> allow
smoke_test_script "validate-artifact-structure" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$A"'","old_string":"# Vision","new_string":"# Vision (revised)"}}' \
  "allow"

# Edit whose old_string is not in the file -> allow (the Edit itself will fail)
smoke_test_script "validate-artifact-structure" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$A"'","old_string":"not present","new_string":""}}' \
  "allow"

smoke_test_summary
