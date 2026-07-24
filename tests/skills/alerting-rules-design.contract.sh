#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "alerting-rules-design" \
  "Before rounding to the published 14.4, what does the raw arithmetic 0.02 x 672 actually work out to for the fast-burn multiplier?" \
  "13.44"

smoke_test_summary
