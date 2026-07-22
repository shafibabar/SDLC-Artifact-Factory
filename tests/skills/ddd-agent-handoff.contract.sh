#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "ddd-agent-handoff" \
  "Per this skill's handoff protocol, which subdomain classification should always default to Collaboration mode, regardless of how stable or familiar the pairing is?" \
  "Core"

smoke_test_summary
