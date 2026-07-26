#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-routing" \
  "According to this skill, why is a failure to load a Module Federation remote entry treated as a distinct error category from an ordinary React render error inside that remote?" \
  "never"

smoke_test_summary
