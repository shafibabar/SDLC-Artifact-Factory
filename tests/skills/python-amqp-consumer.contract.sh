#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact (references/dlx-retry-topology.md): a per-message
# `expiration` TTL is only evaluated when the message reaches the HEAD of the
# queue, which is why distinct fixed-TTL retry queues per backoff tier are
# preferred over per-message expiration. This detail lives only in the reference,
# not in SKILL.md's body — so a correct answer proves the progressive-disclosure
# split loaded the reference.
smoke_test_skill "python-amqp-consumer" \
  "When would you prefer distinct fixed-TTL retry queues per backoff tier over setting a per-message expiration, and when is a per-message TTL actually evaluated in RabbitMQ?" \
  "checked at the head"

smoke_test_summary
