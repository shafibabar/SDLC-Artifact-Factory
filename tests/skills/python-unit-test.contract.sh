#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the coverage gate's skippable suites are listed
# in references/coverage-gate.md and the script, not in the SKILL.md body, so
# answering requires the folder file. Retire when evals/python-unit-test passes.
smoke_test_skill "python-unit-test" \
  "Which test suite folders may be passed to --skip-suite of check-python-coverage.sh?" \
  "performance"

smoke_test_summary
