#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "structured-logging-design" \
  "What node filesystem path does the Fluent Bit DaemonSet read to collect Kubernetes container logs, and why is writing logs to a file instead of stdout non-compliant?" \
  "/var/log/containers"

smoke_test_summary
