#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a references/-only fact (go-task-workers.md): the exact Conductor task
# status a Go worker posts to stop retrying an unfixable/poisoned input
# immediately, as opposed to the plain FAILED that triggers taskdef retries.
# This status name appears only in references/, never in SKILL.md.
smoke_test_skill \
  "conductor-workflow-authoring" \
  "When a Conductor Go task worker receives a poisoned/unfixable input that should not be retried, exactly what task status string does it post back to Conductor so retrying stops immediately (instead of the plain FAILED that triggers the task definition's retries)?" \
  "FAILED_WITH_TERMINAL_ERROR"

smoke_test_summary
