#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-integration-test" \
  "According to this skill, what is the default test-isolation strategy for a Postgres-backed integration test, and what is the one case where it breaks down?" \
  "rollback"

smoke_test_summary
