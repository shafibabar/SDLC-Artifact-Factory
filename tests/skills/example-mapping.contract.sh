#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "example-mapping" \
  "According to this skill, does example mapping run before or after acceptance criteria are finalized?" \
  "before"

smoke_test_summary
