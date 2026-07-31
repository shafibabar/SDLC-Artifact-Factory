#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a references/-only detail: the specific Go gRPC helper that maps a
# context deadline/cancellation error to the correct gRPC status code. This
# name appears only in references/streaming-errors-mesh.md, never in SKILL.md.
smoke_test_skill \
  "go-grpc-handler" \
  "In a streaming or unary method, which Go gRPC helper function does this skill use to convert a context deadline/cancellation error (ctx.Err) into the correct gRPC status so it returns DeadlineExceeded or Canceled?" \
  "status.FromContextError"

smoke_test_summary
