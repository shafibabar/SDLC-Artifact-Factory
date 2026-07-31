#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "go-project-structure" \
  "According to this skill's 12-factor Kubernetes compliance checklist, what specific violation example is given for the config-from-environment-variables requirement?" \
  "config.yaml"

smoke_test_summary
