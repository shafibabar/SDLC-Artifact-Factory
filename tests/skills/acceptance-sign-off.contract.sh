#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "acceptance-sign-off" \
  "According to this skill's checklist, should exploratory-session findings be treated differently from scripted UAT scenario results, or the same way?" \
  "same"

smoke_test_summary
