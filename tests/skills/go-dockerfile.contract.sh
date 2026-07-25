#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-dockerfile" \
  "According to this skill, why must a Go service's Dockerfile use exec-form ENTRYPOINT instead of shell-form ENTRYPOINT?" \
  "SIGTERM"

smoke_test_summary
