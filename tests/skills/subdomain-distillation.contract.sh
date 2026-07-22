#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "subdomain-distillation" \
  "According to this skill, which of the three subdomain types deserves the deepest modeling investment?" \
  "Core"

smoke_test_summary
