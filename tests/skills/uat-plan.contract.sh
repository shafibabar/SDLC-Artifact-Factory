#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "uat-plan" \
  "According to this skill, who actually explores during an exploratory session -- an agent reasoning over the UI, or a human executor?" \
  "human"

smoke_test_summary
