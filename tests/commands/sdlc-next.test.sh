#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Same real state as sdlc-status: an incomplete build_checklist chunk exists,
# so /sdlc-next must name it and refuse to start building — not recommend a
# phase-driver command.
smoke_test_command_contains \
  "/sdlc-next" \
  "ai-ml-architect" \
  "sdlc-next"

smoke_test_summary
