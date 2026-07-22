#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "zero-trust-design" \
  "Which service mesh provides automatic mTLS between services in this plugin's default stack?" \
  "Linkerd"

smoke_test_summary
