#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-dashboard-components" \
  "According to this skill, what exactly must every chart ship alongside it, with no exceptions?" \
  "table"

smoke_test_summary
