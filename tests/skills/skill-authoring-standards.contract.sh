#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a Skill Collision symptom that exists only in
# references/vocabulary-and-collision-detection.md, not in SKILL.md body.
# A passing result proves the progressive-disclosure split is followed.
smoke_test_skill \
  "skill-authoring-standards" \
  "Name one symptom that indicates a latent Skill Collision has occurred in a plugin's skill library." \
  "answers questions it does not own"

smoke_test_summary
