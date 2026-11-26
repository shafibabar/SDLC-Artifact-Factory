#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the moq flag guidance in references/moq-generation.md: what the -stub flag
# changes about a method whose func field is nil.
smoke_test_skill \
  "mock-generation" \
  "According to this skill's moq reference, what does a generated moq method with a nil func field do when the -stub flag is NOT used? Answer with the single Go term for that behaviour." \
  "panic"

smoke_test_summary
