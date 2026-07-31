#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the proto→research lifecycle distinguishes attribute
# grounding with implicit prefixes — a proto-persona attribute reads "We believe…" and a
# research-persona (interview-grounded) attribute reads "We observed…". The prefix table
# lives only in references/persona-fields-and-grounding.md, not in the SKILL.md body.
smoke_test_skill "user-persona" \
  "In a persona artifact, what implicit two-word phrase prefixes each attribute of a research-persona (interview-grounded), distinguishing it from a proto-persona's assumption-based attributes?" \
  "We observed"

smoke_test_summary
