#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Invoked with no arguments -> step 1 requires asking the user for the
# decision title before doing anything else (no agent invocation yet).
smoke_test_command_contains \
  "/sdlc-adr" \
  "decision title" \
  "sdlc-adr"

smoke_test_summary
