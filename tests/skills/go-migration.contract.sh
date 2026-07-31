#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-migration" \
  "According to this skill, why must CREATE INDEX CONCURRENTLY be used instead of a plain CREATE INDEX on a live table?" \
  "SHARE"

smoke_test_summary
