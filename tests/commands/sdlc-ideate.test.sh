#!/bin/bash
# Strategy not yet approved in the product manifest: /sdlc-ideate must stop and point back to /sdlc-strategy.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
smoke_test_product_fixture "$SCRATCH_DIR/product" strategy '{"strategy":{"status":"in-progress"}}'
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-ideate" \
  "/sdlc-strategy" \
  "sdlc-ideate"

smoke_test_summary
