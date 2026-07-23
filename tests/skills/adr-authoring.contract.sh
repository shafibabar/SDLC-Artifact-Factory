#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "adr-authoring" \
  "According to this skill, when an Architecture Principle needs to change as understanding improves, is it superseded like an ADR, or revised in place?" \
  "revised in place"

smoke_test_summary
