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

# Complete frontmatter -> allow
smoke_test_script "validate-artifact-structure" \
  '{"tool_input":{"file_path":"/x/artifacts/p/strategy/v.md","content":"---\nname: v\nversion: 1.0.0\nphase: strategy\nowner: x\ncreated: 2026-07-20\n---\n"}}' \
  "allow"

# Complete frontmatter plus the optional summary field -> allow
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

smoke_test_summary
