#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Invoked with no arguments -> the target (artifact path or phase name) is
# unset, step 1 requires asking the user rather than defaulting to a
# general-purpose review subagent dispatch.
smoke_test_command_contains \
  "/sdlc-review" \
  "phase name" \
  "sdlc-review"

smoke_test_summary
