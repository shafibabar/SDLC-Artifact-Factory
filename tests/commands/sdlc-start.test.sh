#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: first_product.status is "Not yet started" -> does NOT match the
# "stop, product already in progress" condition, so /sdlc-start with no
# arguments must proceed to step 2 and ask for the problem statement.
smoke_test_command_contains \
  "/sdlc-start" \
  "problem statement" \
  "sdlc-start"

smoke_test_summary
