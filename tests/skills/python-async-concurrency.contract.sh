#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: when a worker process in a ProcessPoolExecutor
# dies (OOM / C-extension segfault), the pool raises BrokenProcessPool and every
# pending future fails, so the pool must be recreated. This is documented only in
# references/gil-and-processpool.md ("Practical process-pool hygiene"), never in
# the SKILL.md body — the body names ProcessPoolExecutor and the GIL but says
# nothing about the crash/BrokenProcessPool failure mode.
smoke_test_skill "python-async-concurrency" \
  "In this repo's Python async concurrency guidance, if one worker process in the ProcessPoolExecutor crashes (OOM or a C-extension segfault), what exception does the pool raise and what becomes of the pending futures?" \
  "BrokenProcessPool"

smoke_test_summary
