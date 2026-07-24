#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "analytics-requirements" \
  "According to this skill, is the One Metric That Matters the same thing as the North Star Metric, or are they distinct — and if distinct, what's the key difference?" \
  "rotat"

smoke_test_summary
