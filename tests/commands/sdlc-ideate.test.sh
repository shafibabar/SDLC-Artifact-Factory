#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: no Strategy artifacts exist -> must halt and tell the user to
# run /sdlc-strategy first, per the command's own literal wording.
smoke_test_command_contains \
  "/sdlc-ideate" \
  "/sdlc-strategy" \
  "sdlc-ideate"

smoke_test_summary
