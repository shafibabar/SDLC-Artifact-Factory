#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the classification-to-controls mapping (references/classification-to-controls.md):
# the specific masking control assigned to Restricted-level fields read by an under-cleared
# Subject. This mapping detail lives ONLY in references/, not in SKILL.md's body.
smoke_test_skill "data-classification" \
  "In the classification-to-control mapping, what masking control is applied to a Restricted field when it is read by a Subject whose clearance is below Restricted?" \
  "field-level masking"

smoke_test_summary
