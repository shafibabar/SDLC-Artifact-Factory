#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "user-journey-mapping" \
  "In a Service Blueprint, what is the name of the boundary line that separates the back-stage actions from the support processes beneath them?" \
  "Line of Internal Interaction"
smoke_test_summary
