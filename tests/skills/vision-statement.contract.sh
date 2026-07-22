#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "vision-statement" \
  "What is the maximum word count for a vision statement per this skill's Length quality criterion?" \
  "60 words"

smoke_test_summary
