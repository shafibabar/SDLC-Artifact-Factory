#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-api-client" \
  "According to this skill, what specifically goes wrong with the backend's refresh-token rotation if N concurrent 401s each independently call refreshAccessToken() instead of sharing one in-flight refresh?" \
  "rotation"

smoke_test_summary
