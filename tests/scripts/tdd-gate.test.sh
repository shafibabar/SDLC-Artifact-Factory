#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# No test file exists -> deny
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/x.go"}}' "deny" "No test file found"

# Test file itself being written -> allow (it IS the test)
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/x_test.go"}}' "allow"

# Test file exists first -> implementation write allowed
touch "$SCRATCH_DIR/y_test.go"
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/y.go"}}' "allow"

# Non-Go/TS file -> not in scope, allow
smoke_test_script "tdd-gate" '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/README.md"}}' "allow"

smoke_test_summary
