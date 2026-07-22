#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "css-styling-strategy" \
  "According to this skill, which CSS isolation mechanism does this plugin use for micro-frontends, and why not Shadow DOM?" \
  "Modules"

smoke_test_summary
