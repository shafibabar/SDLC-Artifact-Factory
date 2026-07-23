#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "access-control-model" \
  "According to this skill, what does Go always have that Java or Kotlin examples of Domain Primitives don't have to guard against in the same way, making the zero-value trap a real risk for a type like TenantID?" \
  "accessible zero value"

smoke_test_summary
