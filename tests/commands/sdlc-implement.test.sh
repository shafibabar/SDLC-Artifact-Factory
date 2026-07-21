#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: Design phase not complete -> must halt and tell the user to
# run /sdlc-design first, per the command's own literal wording.
smoke_test_command_contains \
  "/sdlc-implement" \
  "/sdlc-design" \
  "sdlc-implement"

smoke_test_summary
