#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-contract-test" \
  "According to this skill, before a service deploys, what does the can-i-deploy check ask the Pact Broker, and what does it prevent?" \
  "compatible"

smoke_test_summary
