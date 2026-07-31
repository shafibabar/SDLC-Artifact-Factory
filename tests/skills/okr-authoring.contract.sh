#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "okr-authoring" \
  "A binary pass/fail Key Result like achieving SOC 2 Type II certification is being graded on the 0.0-1.0 scale at quarter-end. How is it graded, and what credit is given for effort when the certification was not achieved?" \
  "no partial credit"
smoke_test_summary
