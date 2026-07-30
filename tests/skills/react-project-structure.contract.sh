#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-project-structure" \
  "According to this skill, what severity level does exhaustive-deps run at in the ESLint config, and why is it not set to error like rules-of-hooks?" \
  "warn"

smoke_test_summary
