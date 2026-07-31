#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "threat-modeling" \
  "Under the STRIDE-per-element grid discipline, which two STRIDE categories principally apply to an external entity element (such as a user's browser or Google Drive)?" \
  "Spoofing and Repudiation"
smoke_test_summary
