#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/states-and-edge-cases.md: the five UI states (Scott Hurff)
# that every screen in the screen/state inventory must design for. The name of
# the fifth state — the fully-populated success state — is "ideal state", a term
# that appears only in references/, never in the SKILL.md body.
smoke_test_skill "ux-flow-design" \
  "In the screen/state inventory, besides the blank, loading, partial, and error states, what does this skill call the fifth UI state — the fully-populated success version of a screen that most mockups show?" \
  "ideal state"

smoke_test_summary
