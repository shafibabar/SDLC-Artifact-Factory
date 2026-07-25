#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-middleware" \
  "According to this skill's RateLimit implementation, why is the subject lookup from context always guaranteed to succeed, never needing an error check?" \
  "mounted"

smoke_test_summary
