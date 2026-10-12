#!/bin/bash
# Ideate not yet approved: /sdlc-design must stop and point back to /sdlc-ideate.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
smoke_test_product_fixture "$SCRATCH_DIR/product" ideate '{"strategy":{"status":"approved","approved_on":"2026-10-12"},"ideate":{"status":"in-progress"}}'
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-design" \
  "/sdlc-ideate" \
  "sdlc-design"

smoke_test_summary
