#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a references/-only fact: Patton's three working layers of resolution
# (big picture -> backbone -> details). The SKILL.md body describes the two
# axes but never enumerates the three layers, so answering requires
# references/map-structure-and-backbone.md.
smoke_test_skill \
  "story-mapping" \
  "According to this skill, what are the three working layers Patton uses to build up a story map, from the most zoomed-out level down to the most detailed?" \
  "big picture"

smoke_test_summary
