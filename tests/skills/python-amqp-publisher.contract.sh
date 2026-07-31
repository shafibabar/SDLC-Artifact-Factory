#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the exact exception aio-pika raises for an
# unroutable mandatory message under publisher confirms. The SKILL.md body only
# says publish "raises on an unroutable message" and defers the exact type to
# references/publishing-and-confirms.md ("Exact type: the reference") — so the
# class name aio_pika.exceptions.DeliveryError proves the reference was consulted,
# not the body. This is the central Python-vs-Go divergence: Go surfaces returns
# on a separate NotifyReturn channel; aio-pika folds them into the awaited publish
# as this exception.
smoke_test_skill "python-amqp-publisher" \
  "In aio-pika under publisher confirms, what exception is raised when a message published with mandatory=True routes to zero queues? Give the fully-qualified exception class name." \
  "aio_pika.exceptions.DeliveryError"

smoke_test_summary
