#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-accessibility" \
  "According to this skill, where must keyboard focus return to when a modal closes, and why must document.activeElement be captured at mount time rather than at close time?" \
  "trigger"

smoke_test_summary
