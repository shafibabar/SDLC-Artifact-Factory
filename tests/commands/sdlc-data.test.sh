#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Real state: neither Design-phase pipeline architecture nor Implement-phase
# data schemas exist -> must tell the user what's missing and stop, not
# invoke data-engineer. This command has no single literal "run /sdlc-X"
# next-step string (unlike the others), so assert on the Design-phase
# prerequisite it names first in its own gating step.
smoke_test_command_contains \
  "/sdlc-data" \
  "Design phase" \
  "sdlc-data"

smoke_test_summary
