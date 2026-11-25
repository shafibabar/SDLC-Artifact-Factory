#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "test-pyramid" \
  "According to this skill's test-strategy template, how many automatic retries does the end-to-end layer get? Answer with a single digit." \
  "1"

smoke_test_summary
