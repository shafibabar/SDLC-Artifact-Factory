#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-event-consumer" \
  "According to this skill's liveness heartbeat worked example, how many missed heartbeat pulses are treated as noise versus a real signal that the main loop stopped executing?" \
  "several"

smoke_test_summary
