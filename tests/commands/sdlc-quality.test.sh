#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: Implement phase not complete -> must halt and tell the user to
# run /sdlc-implement first, per the command's own literal wording.
smoke_test_command_contains \
  "/sdlc-quality" \
  "/sdlc-implement" \
  "sdlc-quality"

smoke_test_summary
