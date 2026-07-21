#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: first_product.status is "Not yet started" -- this must be
# treated as "no product context exists", not as an existing context to
# build strategy artifacts against. Tests a real ambiguity in the command's
# own wording ("first_product or equivalent" exists as a block regardless
# of status).
smoke_test_command_contains \
  "/sdlc-strategy" \
  "/sdlc-start" \
  "sdlc-strategy"

smoke_test_summary
