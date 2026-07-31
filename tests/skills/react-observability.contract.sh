#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Tests a non-obvious constraint from Standard 3's per-remote scoped tracers rule.
# The answer lives in the SKILL.md body — verifies the MFE-specific OTel pattern is resident.
smoke_test_skill \
  "react-observability" \
  "According to this skill, why must a Module Federation remote call trace.getTracer() instead of registering its own WebTracerProvider?" \
  "overwrite"

smoke_test_summary
