#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "beta-program-design" \
  "According to this skill's pivot decision framework, what four hypotheses might be suspect when a stage fails its graduation bar?" \
  "Process"

smoke_test_summary
