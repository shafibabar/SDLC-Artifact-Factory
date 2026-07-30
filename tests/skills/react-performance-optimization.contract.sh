#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-performance-optimization" \
  "According to this skill's worked React.memo example, what specifically defeats the shallow prop comparison even though the visible content never changes?" \
  "inline"

smoke_test_summary
