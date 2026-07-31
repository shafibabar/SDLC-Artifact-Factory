#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "risk-register" \
  "What is Fairbanks' name for the concentric-ring triage diagram that places the highest-priority, most architecturally-significant risks at the center and cheap-to-reverse 'just write it and see' elements at the rim?" \
  "Bullseye"
smoke_test_summary
