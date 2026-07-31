#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "progressive-delivery" \
  "What is the minimum hold time in minutes before a canary can advance from stage 1 (5% weight) to stage 2 (25% weight)?" \
  "15"

smoke_test_summary
