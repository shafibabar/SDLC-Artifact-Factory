#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/throughput-and-ci.md: the exact pytest-benchmark gate flag
# and value (--benchmark-compare-fail=median:12%). The SKILL.md body names the
# 12%-on-median tolerance and cites --benchmark-compare-fail by name, but the
# literal flag=value string that actually fails CI lives ONLY in the reference
# (verified absent from the body). Answering requires the progressively-
# disclosed reference, not the body alone.
smoke_test_skill "python-performance-test" \
  "What is the exact pytest-benchmark command-line flag and value the CI job uses to fail the build when a tracked benchmark's median regresses past the reasoned tolerance?" \
  "--benchmark-compare-fail=median:12%"

smoke_test_summary
