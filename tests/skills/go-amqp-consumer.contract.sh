#!/bin/bash
# Contract test for the go-amqp-consumer skill.
# Probes a references/-only fact: the DLX retry-topology pitfall that a
# Nack/Reject with requeue=true bypasses the dead-letter-exchange. This detail
# lives only in references/dlx-retry-topology.md, NOT in SKILL.md's body —
# verify with:
#   grep -i "never reach the DLX" skills/go-amqp-consumer/SKILL.md   # must be ABSENT
#   grep -i "never reach the DLX" skills/go-amqp-consumer/references/ # present
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "go-amqp-consumer" \
  "In the dead-letter-exchange delayed-retry topology, why does rejecting or nacking a message with requeue=true fail to route it to the DLX? What requeue value must you use instead?" \
  "never reach the DLX"

smoke_test_summary
