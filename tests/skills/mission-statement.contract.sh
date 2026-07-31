#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "mission-statement" \
  "In this skill's worked mission derivation for the data-estate / compliance platform, which two verbs are chosen as the single primary action, and why is that pair treated as one action rather than a menu?" \
  "catalogs and classifies"
smoke_test_summary
