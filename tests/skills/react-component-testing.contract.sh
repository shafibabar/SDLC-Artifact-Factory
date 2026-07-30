#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "react-component-testing" \
  "According to this skill, why is @testing-library/user-event preferred over fireEvent for simulating a user typing into a field?" \
  "keydown"

smoke_test_summary
