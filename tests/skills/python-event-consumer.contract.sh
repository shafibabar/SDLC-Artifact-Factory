#!/bin/bash
# Contract test for the python-event-consumer skill.
#
# Probes a reference-only fact: what KIND of function a CPU-bound per-message
# task must be to be submitted to a ProcessPoolExecutor, and why. The answer
# ("a top-level, importable function", because ProcessPoolExecutor pickles the
# callable and its arguments to cross the process boundary) lives ONLY in
# references/worker-pools-and-dlq.md, never in SKILL.md's body — so a correct
# answer proves the progressive-disclosure split loads reference content.
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "python-event-consumer" \
  "For CPU-bound per-message work dispatched to a ProcessPoolExecutor, what kind of function must the target callable be, and why can't a lambda or closure be used?" \
  "top-level, importable function"

smoke_test_summary
