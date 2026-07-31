#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "ci-pipeline" \
  "What is the maximum branch lifetime enforced by the trunk-based development policy in the ci-pipeline skill?" \
  "one calendar day"

smoke_test_summary
