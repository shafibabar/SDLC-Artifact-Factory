#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the toil threshold — a specific numeric fact added in the v1.1.0 refactor.
# A runbook procedure executed more than 3 times per week consistently has crossed
# the toil threshold and must be escalated as a platform automation candidate.
smoke_test_skill "runbook-authoring" \
  "What is the toil threshold that triggers escalating a runbook procedure as a platform automation candidate, and what happens at that point?" \
  "3 times per week"

smoke_test_summary
