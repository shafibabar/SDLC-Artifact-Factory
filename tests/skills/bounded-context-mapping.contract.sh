#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "bounded-context-mapping" \
  "In the linguistic fracture line technique described by this skill, what is the name of the document or table produced in Step 2 that places definitions from different domain areas side by side to reveal where the same term has diverging meanings?" \
  "Term Divergence Table"

smoke_test_summary
