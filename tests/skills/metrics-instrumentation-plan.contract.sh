#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a non-obvious fact from the newly added DORA delivery metrics content:
# the specific commit-message convention required to make Change Failure Rate
# computable from the cd-pipeline environment repo commit log.
smoke_test_skill "metrics-instrumentation-plan" \
  "What tag must appear in a cd-pipeline rollback commit message subject line for Change Failure Rate to be computable from the environment repo commit log?" \
  "[ROLLBACK]"

smoke_test_summary
