#!/bin/bash
# Design not yet approved: /sdlc-implement must stop and point back to /sdlc-design.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
smoke_test_product_fixture "$SCRATCH_DIR/product" design '{"strategy":{"status":"approved","approved_on":"2026-10-12"},"ideate":{"status":"approved","approved_on":"2026-10-12"},"design":{"status":"in-progress"}}'
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-implement" \
  "/sdlc-design" \
  "sdlc-implement"

smoke_test_summary
