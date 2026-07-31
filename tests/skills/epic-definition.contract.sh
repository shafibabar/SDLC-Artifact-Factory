#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "epic-definition" \
  "In Mike Cohn's SPIDR story-splitting pattern, what do the five letters stand for?" \
  "Paths, Interfaces, Data"
smoke_test_summary
