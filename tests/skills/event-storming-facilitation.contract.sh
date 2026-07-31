#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "event-storming-facilitation" \
  "In Big Picture Event Storming, how are pivotal events marked on the timeline, and what boundary do those marks first hint at?" \
  "vertical line"
smoke_test_summary
