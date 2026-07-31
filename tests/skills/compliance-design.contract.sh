#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the materiality rubric from references/materiality-and-risk-selection.md.
# The SKILL.md body names materiality as the selection step and says the most
# material risks earn a `gate`, but the concrete three-axis scoring rubric —
# harm reversibility, BLAST RADIUS, and regulatory consequence — exists ONLY in
# the reference file (the phrase "blast radius" never appears in the body). A
# passing test proves the progressive-disclosure split is functional: the
# reference is loaded and consulted when the scoring detail is needed.
smoke_test_skill \
  "compliance-design" \
  "According to this skill's materiality rubric, what are the three axes on which a candidate control's risk is scored to decide its enforcement mode?" \
  "blast radius"

smoke_test_summary
