#!/bin/bash
# Contract test: value-stream-map
# Probes a non-obvious fact from the newly added DORA benchmarks section:
# the Change Failure Rate range for Low performers (46-60%) — a specific
# threshold that appears verbatim in the DORA cluster table and is not
# guessable from the skill name alone.
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "value-stream-map" \
  "According to the DORA cluster benchmarks in the value-stream-map skill, what is the Change Failure Rate range for Low performers?" \
  "46"
smoke_test_summary
