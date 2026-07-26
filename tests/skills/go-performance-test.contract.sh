#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-performance-test" \
  "According to this skill, what does this skill own versus go-performance-optimization and go-makefile in the three-way benchmarking boundary?" \
  "baseline"

smoke_test_summary
