#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the Object Mother pattern example from references/fixture-patterns-catalogue.md.
# The tenant-level Object Mother factory function (SeedActiveTenant) exists ONLY in the
# reference file, not in the SKILL.md body — a passing test proves the progressive-disclosure
# split is functional: the reference file is loaded and consulted when needed.
smoke_test_skill \
  "test-fixture-design" \
  "According to this skill's fixture-patterns-catalogue, what is the name of the Object Mother factory function provided for creating a fully-configured active tenant record in the test database?" \
  "SeedActiveTenant"

smoke_test_summary
