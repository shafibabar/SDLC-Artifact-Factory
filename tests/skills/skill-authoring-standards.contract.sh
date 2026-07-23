#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "skill-authoring-standards" \
  "According to this skill, roughly how many lines of body content (below the frontmatter) should prompt a SKILL.md to be treated as a split candidate for references/?" \
  "200"

smoke_test_summary
