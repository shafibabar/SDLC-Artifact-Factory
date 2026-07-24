#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "acceptance-sign-off" \
  "According to this skill, instead of hand-copying the sign-off template and its checklist, what should you run to generate a new sign-off doc?" \
  "scaffold-signoff.sh"

smoke_test_summary
