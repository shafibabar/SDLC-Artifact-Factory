#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the newly added platform-as-product SLO targets.
# The CI pipeline P95 target of < 10 minutes is a specific, non-obvious threshold
# added from Platform Engineering (Fournier, Nowland) research — not guessable from
# the skill name alone.
smoke_test_skill "slo-definition" \
  "What is the platform SLO target for CI pipeline P95 duration?" \
  "10 min"

smoke_test_summary
