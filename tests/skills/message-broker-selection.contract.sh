#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references-only fact: the AMQP 0-9-1 topic-exchange wildcard
# semantics live in references/log-vs-queue-model.md, NOT in SKILL.md body.
# The body teaches the log-vs-queue selection axis; the exact routing-key
# wildcard behaviour is reference material reached only by loading references/.
smoke_test_skill "message-broker-selection" \
  "In an AMQP topic exchange, what does the # wildcard match in a routing-key binding pattern, and how does that differ from the * wildcard?" \
  "zero or more words"

smoke_test_summary
