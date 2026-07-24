#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "bdd-feature-file" \
  "According to this skill, what are the three checkable criteria that determine a specification is ready to leave a Specification Workshop and become an automated scenario?" \
  "single rule"

smoke_test_summary
