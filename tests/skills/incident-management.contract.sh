#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "incident-management" \
  "Which of the six postmortem trigger criteria does the skill identify as the most important, and what makes it more valuable than an alert that worked correctly?" \
  "monitoring failure"

smoke_test_summary
