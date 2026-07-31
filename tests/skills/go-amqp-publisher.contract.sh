#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the amqp091-go channel method that registers
# the listener receiving unroutable (basic.return) messages. The SKILL.md body
# teaches the mandatory-flag + basic.return contract conceptually but names no
# Go client API for it — the "NotifyReturn" method lives only in
# references/publishing-and-confirms.md. A correct answer proves the
# progressive-disclosure split reached the reference file.
smoke_test_skill "go-amqp-publisher" \
  "In the amqp091-go Go client, which Channel method registers the listener channel that receives unroutable messages the broker returns for publishes sent with the mandatory flag?" \
  "NotifyReturn"

smoke_test_summary
