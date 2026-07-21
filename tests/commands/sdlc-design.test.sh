#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: Ideate phase not complete -> must halt and tell the user to
# run /sdlc-ideate first, per the command's own literal wording.
smoke_test_command_contains \
  "/sdlc-design" \
  "/sdlc-ideate" \
  "sdlc-design"

smoke_test_summary
