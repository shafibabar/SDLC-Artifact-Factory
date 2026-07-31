#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/match-merge-survivorship.md: the Fellegi-Sunter three-band
# match model. The middle "clerical review" band (between auto-match and
# auto-non-match, routing a pair to a human steward) exists ONLY in references/,
# not in SKILL.md — the body says only "human-review" without naming the band.
smoke_test_skill "canonical-data-model" \
  "In probabilistic identity resolution using the Fellegi-Sunter framework, what is the middle match band called that sits between auto-match and auto-non-match and routes a candidate pair to a human Data Steward?" \
  "clerical review"

smoke_test_summary
