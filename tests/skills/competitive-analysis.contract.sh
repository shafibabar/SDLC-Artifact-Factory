#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the Competitive Risks table in references/competitive-analysis-template.md:
# the worked artifact's mitigation for the consultant substitute ("Consultant
# channel resists displacement") is to position consultants as a channel, not a
# competitor. The SKILL.md body names substitutes and the consultant example but
# never states this channel-vs-competitor mitigation — it lives only in the
# reference template, so a correct answer proves progressive disclosure is loading.
smoke_test_skill "competitive-analysis" \
  "In the worked Data Estate competitive analysis, when a consultant channel resists displacement, how does the Competitive Risks table say to position consultants?" \
  "channel, not a competitor"

smoke_test_summary
