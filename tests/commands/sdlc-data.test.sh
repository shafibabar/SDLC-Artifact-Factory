#!/bin/bash
# Implement not yet approved: /sdlc-data must stop and point back to /sdlc-implement.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
smoke_test_product_fixture "$SCRATCH_DIR/product" implement '{"strategy":{"status":"approved","approved_on":"2026-10-12"},"ideate":{"status":"approved","approved_on":"2026-10-12"},"design":{"status":"approved","approved_on":"2026-10-12"},"implement":{"status":"in-progress"}}'
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-data" \
  "/sdlc-implement" \
  "sdlc-data"

smoke_test_summary
