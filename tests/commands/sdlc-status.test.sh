#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real repo state: build_checklist has one incomplete chunk (22, ai-ml-architect).
# /sdlc-status must name it (branch 1 of its own logic), not report a fully-built factory.
smoke_test_command_contains \
  "/sdlc-status" \
  "ai-ml-architect" \
  "sdlc-status"

smoke_test_summary
