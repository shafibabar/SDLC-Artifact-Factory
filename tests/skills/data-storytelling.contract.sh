#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes references/knaflic-techniques.md: the Gestalt principle Knaflic invokes
# to justify removing a chart's plot border (whitespace already bounds the plot).
# This decluttering/Gestalt detail lives only in references/, not the SKILL body.
smoke_test_skill "data-storytelling" \
  "Which Gestalt principle does Knaflic invoke to explain why a chart's plot border is redundant and should be removed, since whitespace already bounds the plot area?" \
  "enclosure"
smoke_test_summary
