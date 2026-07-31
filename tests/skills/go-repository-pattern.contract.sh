#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-repository-pattern" \
  "According to this skill, what design pattern does a repository implementation apply, per Robert Martin's terminology, and why does the repository barely need its own unit tests?" \
  "Humble Object"

smoke_test_summary
