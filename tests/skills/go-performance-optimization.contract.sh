#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-performance-optimization" \
  "According to this skill, what is the measure-first hard gate for an optimization change, and what happens to a PR that claims to be faster with no numbers?" \
  "benchmark"

smoke_test_summary
