#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "ddd-agent-handoff" \
  "If two agents' terms for the same concept conflict, which single skill is the tiebreaker?" \
  "glossary-management"

smoke_test_summary
