#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "miro-board-notation" \
  "According to this skill, which Miro element type should be used to group other items into a named, boundable region like a Bounded Context or a swimlane?" \
  "Frame"

smoke_test_summary
