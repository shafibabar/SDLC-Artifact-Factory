#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-component-design" \
  "According to this skill's composition-pattern decision table, what is the exact scenario that calls for a render prop / function-as-child instead of a custom hook?" \
  "caller must control"

smoke_test_summary
