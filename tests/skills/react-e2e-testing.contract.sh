#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-e2e-testing" \
  "According to this skill's worked cross-remote journey example, what action is performed in one fragment and then observed as a visible effect in a different fragment?" \
  "compliance"

smoke_test_summary
