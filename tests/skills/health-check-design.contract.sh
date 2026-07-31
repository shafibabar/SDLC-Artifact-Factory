#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "health-check-design" \
  "What is the formula for setting terminationGracePeriodSeconds relative to the application's drain timeout, and why is a buffer needed?" \
  "drain_timeout_seconds + 5"
smoke_test_summary
