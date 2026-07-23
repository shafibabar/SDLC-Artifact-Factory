#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "adr-authoring" \
  "According to this skill, instead of hand-counting the next ADR-NNN when starting a new ADR, what should you run?" \
  "scaffold-adr.sh"

smoke_test_summary
