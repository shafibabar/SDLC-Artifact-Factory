#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "aggregate-design" \
  "According to this skill's worked examples, is ExtractedEntity designed as its own separate Aggregate, or as a locally-identified child Entity inside DataAsset?" \
  "child"

smoke_test_summary
