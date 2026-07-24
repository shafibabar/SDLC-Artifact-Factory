#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "acceptance-criteria" \
  "According to this skill, what script should you run to generate a new acceptance-criteria doc pre-filled with story metadata, instead of hand-copying the template?" \
  "scaffold-criteria.sh"

smoke_test_summary
