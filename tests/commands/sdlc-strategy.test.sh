#!/bin/bash
# With no product in the repo, /sdlc-strategy must send the user to /sdlc-start.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
mkdir -p "$SCRATCH_DIR/product" && git -C "$SCRATCH_DIR/product" init -q
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-strategy" \
  "/sdlc-start" \
  "sdlc-strategy"

smoke_test_summary
