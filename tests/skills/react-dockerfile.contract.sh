#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-dockerfile" \
  "According to this skill, why can't a Vite app's API URL simply be set via a build-time environment variable if the same built artifact must be promoted unchanged from staging to production?" \
  "bak"

smoke_test_summary
