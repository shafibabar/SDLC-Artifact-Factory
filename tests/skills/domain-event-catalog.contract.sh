#!/bin/bash
# Contract test for the domain-event-catalog skill.
# Probes a fact that exists ONLY in references/outbox-and-cdc.md — not in SKILL.md body.
# Verified: grep -i "retry_count" skills/domain-event-catalog/SKILL.md → no match.
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "domain-event-catalog" \
  "What column in the outbox_events table tracks how many times the relay has attempted to publish an event, and what is its default value?" \
  "retry_count"

smoke_test_summary
