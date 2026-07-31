#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "nfr-specification" \
  "What is the Change Failure Rate ceiling for a DORA High Performer as specified in the Delivery NFRs category?" \
  "15%"

smoke_test_summary
