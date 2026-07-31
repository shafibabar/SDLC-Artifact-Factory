#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a fact that lives ONLY in references/protobuf-design-and-compat.md
# (the protobuf-implementation-reserved field-number range) and is absent from
# SKILL.md — proving the progressive-disclosure split loads reference content.
smoke_test_skill \
  "grpc-contract-design" \
  "Which specific range of protobuf field numbers is reserved by protobuf itself and must never be used for a message field?" \
  "19000"

smoke_test_summary
