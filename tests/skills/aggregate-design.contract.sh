#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "aggregate-design" \
  "This skill uses one specific word to describe an Aggregate instance where thousands of Commands converge on a single row during a scan. What is that word?" \
  "hotspot"

smoke_test_summary
