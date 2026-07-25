#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-error-handling" \
  "According to this skill's worked example for the nil-interface footgun, what specifically happens if you call .Error() on the nil *ValidationError returned through the error interface?" \
  "panic"

smoke_test_summary
