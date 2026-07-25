#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-service-layer" \
  "According to this skill's worked cache-aside example, what TTL does the handler set when populating the cache?" \
  "30"

smoke_test_summary
