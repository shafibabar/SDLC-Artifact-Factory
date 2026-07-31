#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "feature-flag-design" \
  "According to this skill, which chapter of the Continuous Delivery book is cited as the central motivation for feature flags enabling engineers to commit to trunk daily without breaking anything?" \
  "Ch. 3"
smoke_test_summary
