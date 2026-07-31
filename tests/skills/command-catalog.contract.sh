#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that lives ONLY in references/command-format.md, not in the
# SKILL.md body: the concurrent-duplicate edge case where two simultaneous
# requests with the same commandId both pass the initial Find check before
# either inserts into command_log — resolved by the PRIMARY KEY constraint
# rejecting the losing insert. This cannot be answered from the SKILL.md body
# alone, which only mentions commandId as an idempotency key without implementation
# details.
smoke_test_skill "command-catalog" \
  "When two simultaneous requests carry the same commandId and both pass the initial idempotency check before either writes to command_log, what mechanism prevents the duplicate from being applied?" \
  "PRIMARY KEY"

smoke_test_summary
