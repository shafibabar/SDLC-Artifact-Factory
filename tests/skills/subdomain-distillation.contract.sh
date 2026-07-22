#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "subdomain-distillation" \
  "Per this skill's classification techniques, what one-word test does Vernon suggest asking to identify a Generic subdomain (as in, would you do this to it)?" \
  "outsource"

smoke_test_summary
