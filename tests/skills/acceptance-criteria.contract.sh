#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "acceptance-criteria" \
  "According to this skill, should acceptance criteria be drafted before or after a story's example map is complete?" \
  "after"

smoke_test_summary
