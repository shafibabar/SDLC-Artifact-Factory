#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "information-architecture" \
  "For a quantitative tree test that yields statistically meaningful findability results (not just directional signal), roughly how many participants per segment should you recruit?" \
  "50 participants"
smoke_test_summary
