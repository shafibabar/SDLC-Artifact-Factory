#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-concurrency-patterns" \
  "According to this skill's worked fan-in example, what two source channels were used to verify it, and what was the correct summed total of the merged output?" \
  "36"

smoke_test_summary
