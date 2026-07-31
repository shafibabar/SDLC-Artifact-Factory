#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/resilience-patterns.md — the Circuit Breaker half-open
# behaviour and the concrete per-downstream thresholds live ONLY in the
# reference file. The SKILL.md body names the closed/open/half-open states but
# carries no numbers and no single-probe rule, so a correct answer requires
# reading references/, not the body.
smoke_test_skill "integration-design" \
  "For an external downstream like the Source Catalog, what failure threshold does the integration-design Circuit Breaker configuration use to trip, and when the breaker is half-open how many trial requests does it let through to probe recovery?" \
  "50%"

smoke_test_summary
