#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "document-data-modeling" \
  "In a MongoDB document model, at roughly what number of children per parent should a one-to-squillions relationship be treated as reference-with-the-key-on-the-child rather than embedded or stored as an array of keys in the parent?" \
  "few hundred"
smoke_test_summary
