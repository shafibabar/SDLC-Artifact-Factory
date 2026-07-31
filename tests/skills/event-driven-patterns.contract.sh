#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the pivot-transaction ordering law from references/saga-patterns.md.
# The rule "exactly one pivot per Saga; a Saga with two pivots is really two Sagas"
# lives ONLY in the reference file — the SKILL.md body names the compensatable/
# pivot/retryable classification but never states the one-pivot constraint or its
# consequence. A passing test proves the progressive-disclosure split is functional:
# the reference file is loaded and consulted when the pivot concept is queried.
smoke_test_skill \
  "event-driven-patterns" \
  "According to this skill's in-depth Saga guidance, how many pivot transactions may a single Saga contain, and what does it mean if a design appears to have two pivots?" \
  "two Sagas"

smoke_test_summary
