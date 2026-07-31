#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/flake-and-scope.md-only fact: the exact pytest plugin that
# implements the one-automatic-retry flake policy for e2e journeys, and the flag
# that bounds it to a single rerun. The SKILL.md body describes "exactly one
# automatic retry (bounded, not retry-until-green)" in prose and points to
# references/flake-and-scope.md for "the Python mechanism (a named plugin and
# flag)" -- but carries the plugin name NOWHERE in the body (verified absent:
# `grep pytest-rerunfailures SKILL.md` returns nothing). Only
# references/flake-and-scope.md names "pytest-rerunfailures" with its --reruns 1
# bound. A pass proves the progressive-disclosure split loaded the reference, not
# just the body.
smoke_test_skill "python-e2e-test" \
  "Which pytest plugin implements the one-automatic-retry flake policy for e2e journeys, and what flag bounds it to exactly one rerun?" \
  "pytest-rerunfailures"

smoke_test_summary
