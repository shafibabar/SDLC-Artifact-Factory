#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/moscow-rubric.md: the acronym's origin in the Dynamic
# Systems Development Method (DSDM). This pedigree lives only in references/ —
# the SKILL.md body names the categories and rules but not the framework's
# DSDM origin, so a correct answer proves the progressive-disclosure split
# is functional.
smoke_test_skill "moscow-prioritization" \
  "Which software delivery method did the MoSCoW prioritization technique originate in?" \
  "DSDM"

smoke_test_summary
