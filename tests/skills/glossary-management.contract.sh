#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "glossary-management" \
  "What is this skill's core rule, as a short quoted phrase?" \
  "One term, one meaning"

smoke_test_summary
