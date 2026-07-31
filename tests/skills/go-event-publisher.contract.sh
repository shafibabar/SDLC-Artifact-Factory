#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-event-publisher" \
  "According to this skill's drainOnce worked example, what value does the records slice preallocate its capacity to, and why is that value already known before the loop starts?" \
  "r.batch"

smoke_test_summary
