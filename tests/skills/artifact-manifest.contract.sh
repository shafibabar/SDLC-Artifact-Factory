#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "artifact-manifest" \
  "In this skill's manifest worked example, what is the id of the artifact entry whose status is draft?" \
  "dataestate-risk-register-entry-003"

smoke_test_summary
