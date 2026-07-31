#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "cd-pipeline" \
  "According to the cd-pipeline skill, what Change Failure Rate threshold from the Accelerate DORA cluster analysis defines the boundary for a high performer, and what happens if you exceed it over a two-week window?" \
  "15%"

smoke_test_summary
