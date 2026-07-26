#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-mutation-test" \
  "According to this skill's worked example, can a Go function achieve 100% line coverage and still have a mutant survive? Give the function name from the example." \
  "IsLastPage"

smoke_test_summary
