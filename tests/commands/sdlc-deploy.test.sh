#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: Quality phase gates haven't passed -> must halt and tell the
# user to run /sdlc-quality first, per the command's own literal wording.
smoke_test_command_contains \
  "/sdlc-deploy" \
  "/sdlc-quality" \
  "sdlc-deploy"

smoke_test_summary
