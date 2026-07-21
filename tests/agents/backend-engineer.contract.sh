#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_agent \
  "backend-engineer" \
  "What Go package/type do you use for parallel stages with coordinated cancellation, per your Behavioral Directives?" \
  "errgroup"

smoke_test_summary
