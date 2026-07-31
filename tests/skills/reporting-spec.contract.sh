#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

smoke_test_skill \
  "reporting-spec" \
  "In a report, a section shows the count of gaps still open at each day's close (a point-in-time balance). Can that value simply be summed across all the days in the reporting period to get a period total? What class of fact is it, and what should be done instead?" \
  "semi-additive"

smoke_test_summary
