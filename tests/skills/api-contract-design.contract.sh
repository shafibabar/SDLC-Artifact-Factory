#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "api-contract-design" \
  "According to this skill, what fields does the Operation resource returned by a long-running operation's status-check endpoint carry?" \
  "done"

smoke_test_summary
