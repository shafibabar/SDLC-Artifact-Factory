#!/bin/bash
# Quality not yet approved: /sdlc-deploy must stop and point back to /sdlc-quality.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init
smoke_test_product_fixture "$SCRATCH_DIR/product" quality '{"strategy":{"status":"approved","approved_on":"2026-10-12"},"ideate":{"status":"approved","approved_on":"2026-10-12"},"design":{"status":"approved","approved_on":"2026-10-12"},"implement":{"status":"approved","approved_on":"2026-10-12"},"data":{"status":"approved","approved_on":"2026-10-12"},"quality":{"status":"in-progress"}}'
SMOKE_CWD="$SCRATCH_DIR/product" smoke_test_command_contains \
  "/sdlc-deploy" \
  "/sdlc-quality" \
  "sdlc-deploy"

smoke_test_summary
