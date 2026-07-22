#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-chi-handler" \
  "What Go standard library function does this skill use to cap request body size for DoS protection?" \
  "MaxBytesReader"

smoke_test_summary
