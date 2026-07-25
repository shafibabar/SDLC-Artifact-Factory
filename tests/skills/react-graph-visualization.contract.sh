#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-graph-visualization" \
  "According to this skill's consolidated graph/worker/renderer lifecycle example, why is the graphology graph instance held in a ref instead of created with useMemo?" \
  "discardable"

smoke_test_summary
