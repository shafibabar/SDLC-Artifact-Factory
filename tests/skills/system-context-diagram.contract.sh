#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "system-context-diagram" \
  "In C4 Level 1 System Context notation, what single colour convention is used for an external system element — a system the team integrates with but does not build or own?" \
  "grey"
smoke_test_summary
