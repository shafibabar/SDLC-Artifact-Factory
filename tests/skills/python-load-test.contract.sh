#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "python-load-test" \
  "A single locust process is capped by one CPU core under the GIL. According to this skill, what command-line flag runs an additional locust load-generator process in distributed mode so total offered load isn't bottlenecked by the generator itself?" \
  "--worker"

smoke_test_summary
