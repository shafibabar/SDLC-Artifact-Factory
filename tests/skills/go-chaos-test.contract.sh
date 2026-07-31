#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-chaos-test" \
  "According to this skill's Patterns to Validate table, what two distinct goroutine-count/CPU-utilization signatures distinguish a partial deadlock experiment's result from a livelock experiment's result?" \
  "pegged"

smoke_test_summary
