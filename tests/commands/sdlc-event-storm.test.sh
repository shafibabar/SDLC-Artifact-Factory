#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Invoked with no arguments -> the domain/subdomain to storm is unset, step 1
# requires asking the user which one rather than guessing.
smoke_test_command_contains \
  "/sdlc-event-storm" \
  "subdomain" \
  "sdlc-event-storm"

smoke_test_summary
