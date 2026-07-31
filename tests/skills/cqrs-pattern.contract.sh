#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that exists ONLY in references/projection-patterns.md, not in the
# SKILL.md body: the specific PostgreSQL table name used to track already-processed
# event IDs for projector idempotency (processed_event_ids).
# Confirmed absent from SKILL.md body with: grep -i "processed_event_ids" SKILL.md
smoke_test_skill "cqrs-pattern" \
  "What is the name of the PostgreSQL deduplication table this skill specifies for tracking events a projector has already processed, ensuring idempotent projection updates?" \
  "processed_event_ids"

smoke_test_summary
