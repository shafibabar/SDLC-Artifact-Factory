#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "runbook-authoring" \
  "At what execution frequency threshold does a runbook procedure get escalated as a platform automation candidate to platform-engineering-design?" \
  "3 times per week"
smoke_test_summary
