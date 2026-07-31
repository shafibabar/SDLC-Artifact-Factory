#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "data-quality-rules" \
  "When a record processes successfully but its result fails a quality rule and needs a human judgment call, what is the name of the table it is written to pending Data Steward review, and is that table alerted on age or on volume?" \
  "dq_quarantine"
smoke_test_summary
