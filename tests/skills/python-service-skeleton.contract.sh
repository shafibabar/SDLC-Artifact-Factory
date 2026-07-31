#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the uvicorn graceful-shutdown drain-deadline parameter from
# references/server-and-health.md. The SKILL.md body describes the drain as
# "a uvicorn server setting" sized under the 30s grace period but deliberately
# withholds the exact parameter NAME and value — those live ONLY in the
# reference file. A passing test proves the progressive-disclosure split is
# functional: the reference is loaded and consulted for the concrete setting.
smoke_test_skill \
  "python-service-skeleton" \
  "According to this skill's uvicorn server and health standard, which uvicorn Config parameter bounds the graceful-shutdown request drain, and to what value in seconds does the skill set it so it fits under Kubernetes' 30s termination grace period?" \
  "timeout_graceful_shutdown"

smoke_test_summary
