#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-load-test" \
  "According to this skill, why does the load-test environment use a staging cluster instead of the ephemeral kind cluster go-e2e-test uses?" \
  "capacity"

smoke_test_summary
