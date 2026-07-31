#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-openapi-codegen" \
  "According to this skill, what Go type does a Field Mask field generate into via oapi-codegen, and why not a plain Go map or slice?" \
  "Nullable"

smoke_test_summary
