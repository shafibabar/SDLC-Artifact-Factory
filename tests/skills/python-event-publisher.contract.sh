#!/bin/bash
# Contract test for the python-event-publisher skill.
# Probes a non-obvious fact that lives ONLY in references/aiokafka-producer.md
# (the default partitioner's hashing algorithm), not in the SKILL.md body — so a
# correct answer proves the progressive-disclosure reference is reachable and loaded,
# not just the always-loaded body.
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "python-event-publisher" \
  "Which hashing algorithm does aiokafka's default partitioner use to route a record key (the tenant_id) to a partition?" \
  "murmur2"

smoke_test_summary
