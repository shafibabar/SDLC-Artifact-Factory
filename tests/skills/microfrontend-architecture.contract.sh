#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "microfrontend-architecture" \
  "According to this skill, what is the litmus test for whether a fragment boundary is correctly drawn?" \
  "coordinated"

smoke_test_summary
