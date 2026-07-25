#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-project-structure" \
  "According to this skill, what Go design pattern does embedding an interface (not a concrete type) inside a wrapper struct implement, and what is a worked example type name for this?" \
  "instrumentedRepo"

smoke_test_summary
