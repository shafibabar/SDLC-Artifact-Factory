#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-event-consumer" \
  "According to this skill's liveness heartbeat worked example, what is the exact name of the atomic field that is updated once per fully-completed Run loop iteration (as opposed to the one updated by the independent ticker)?" \
  "lastLoopPulse"

smoke_test_summary
