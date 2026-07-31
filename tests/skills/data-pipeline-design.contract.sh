#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes a fact that lives only in references/fault-tolerance-design.md: the
# window over which the processed_events dedup table must be pruned. The body
# names idempotency and checkpointing as design rules but never states the
# pruning window or the term "redelivery horizon" — that detail is references-only.
smoke_test_skill "data-pipeline-design" \
  "Over what window must a stage's processed_events dedup table be pruned, and what is the name of that window?" \
  "redelivery horizon"
smoke_test_summary
