#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "dora-metrics" \
  "What is the Change Failure Rate range for the Low performer DORA cluster?" \
  "46"
smoke_test_summary
