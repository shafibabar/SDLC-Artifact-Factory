#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "feedback-template" \
  "How does the skill relate Mom-Test question discipline to jtbd-analysis's Backwards JTBD anti-pattern — are they the same safeguard or two different ones, and which guards the input versus the conclusion?" \
  "sequential safeguards"
smoke_test_summary
