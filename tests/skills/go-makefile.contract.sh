#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-makefile" \
  "According to this skill, what is the exact order of targets that make ci runs, and why does vet run before lint rather than after?" \
  "tidy"

smoke_test_summary
