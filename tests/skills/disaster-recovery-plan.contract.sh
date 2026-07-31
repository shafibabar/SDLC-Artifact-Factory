#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "disaster-recovery-plan" \
  "What specific gap does the weekly chaos cadence address, and how many days does that gap last between quarterly drills?" \
  "89-day"
smoke_test_summary
