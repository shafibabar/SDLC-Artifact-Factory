#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-unit-test" \
  "In this skill's complete worked table-driven test example (TestSensitivityLevel_IsHigherThan), what is the name of the test case verifying that an unclassified sensitivity level is never higher than any other level?" \
  "unclassified is lowest"

smoke_test_summary
