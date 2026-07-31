#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "alerting-rules-design" \
  "In the Review Log, what value format is used to record that an alert change came from a specific postmortem rather than from hygiene review alone?" \
  "PM-YYYY-MM-DD"

smoke_test_summary
