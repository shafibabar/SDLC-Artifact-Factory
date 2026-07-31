#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "test-pyramid" \
  "According to this skill's test-strategy template, what is the minimum percentage of introduced mutants that must be killed for a mutation testing run to meet this skill's passing threshold?" \
  "70"

smoke_test_summary
