#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the "golden rule of a good split" from references/story-splitting-patterns.md.
# The rule that every child story must remain a vertical slice — and that splitting by
# architectural layer (database story, then API, then UI) is wrong — exists ONLY in the
# reference file. The SKILL.md body lists the named splitting patterns but never states
# this rule or the phrase "vertical slice". A passing test proves the progressive-
# disclosure split is functional: the reference is loaded and consulted when needed.
smoke_test_skill \
  "user-story-writing" \
  "According to this skill's story-splitting guidance, splitting a story by architectural layer (a database story, then an API story, then a UI story) is wrong because a good split must keep every child story a what?" \
  "vertical slice"

smoke_test_summary
