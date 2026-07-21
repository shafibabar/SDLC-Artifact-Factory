#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: Deploy phase not complete, no canary/staging environment ->
# must halt and tell the user to run /sdlc-deploy first, per the command's
# own literal wording.
smoke_test_command_contains \
  "/sdlc-validate" \
  "/sdlc-deploy" \
  "sdlc-validate"

smoke_test_summary
