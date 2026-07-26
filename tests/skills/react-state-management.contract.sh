#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-state-management" \
  "According to this skill's Context performance-cost worked example, why does a Context value recreated as a fresh object literal on every render defeat React's own optimizations?" \
  "reference"

smoke_test_summary
