#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-domain-model" \
  "According to this skill's worked SensitivityLevel example, how is the private rank() method implemented internally to support IsHigherThan comparisons?" \
  "map"

smoke_test_summary
