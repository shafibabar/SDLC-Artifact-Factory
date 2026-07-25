#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-component-design" \
  "According to this skill's worked VirtualizedList example, what specifically does the render-props pattern let the caller control that a custom hook alone would not?" \
  "rendering"

smoke_test_summary
