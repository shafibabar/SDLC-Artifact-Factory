#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the mockery YAML configuration from references/go-mock-implementation.md.
# The `with-expecter: false` setting exists ONLY in the reference file — the SKILL.md
# body names mockery as the default tool but contains no YAML configuration details.
# A passing test proves the progressive-disclosure split is functional: the reference
# file is loaded and consulted when needed.
smoke_test_skill \
  "mock-generation" \
  "According to this skill's Go mock implementation guide, what value should the with-expecter key in the .mockery.yaml configuration be set to, and what approach does the skill recommend using instead of an EXPECT() builder?" \
  "false"

smoke_test_summary
