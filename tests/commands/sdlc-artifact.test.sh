#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Invoked with no arguments -> action and artifact type are both unclear,
# step 1 requires asking the user rather than guessing either.
smoke_test_command_contains \
  "/sdlc-artifact" \
  "artifact type" \
  "sdlc-artifact"

smoke_test_summary
