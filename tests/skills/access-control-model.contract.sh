#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "access-control-model" \
  "According to this skill, what should you run to generate a new access control design doc, instead of hand-copying the template?" \
  "scaffold-access-control-model.sh"

smoke_test_summary
