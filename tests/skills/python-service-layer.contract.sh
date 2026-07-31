#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: asyncio.TaskGroup, on a child task's failure,
# cancels its siblings and raises the collected failures wrapped in a single
# ExceptionGroup (Python 3.11+). This is documented only in
# references/concurrency-and-context.md, not in the SKILL.md body — the body
# says TaskGroup "cancels its sibling tasks" but never names ExceptionGroup.
smoke_test_skill "python-service-layer" \
  "In this repo's Python service layer, when one child task in an asyncio.TaskGroup query fan-out fails and the group cancels its siblings, what exception type does the group raise at the async-with exit?" \
  "ExceptionGroup"

smoke_test_summary
