#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "platform-engineering-design" \
  "What is the Time-to-First-Deploy threshold at which the golden path is considered to have failed?" \
  "2 days"

smoke_test_summary
