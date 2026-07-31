#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-e2e-test" \
  "According to this skill, what tool provisions the ephemeral cluster an e2e test run deploys into, and what happens to that cluster after the run regardless of pass or fail?" \
  "kind"

smoke_test_summary
