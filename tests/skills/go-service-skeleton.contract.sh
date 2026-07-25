#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-service-skeleton" \
  "According to this skill's worked startup sequence, why does the database connection pool set MaxConnLifetime to an hour instead of leaving connections open indefinitely?" \
  "credential rotation"

smoke_test_summary
