#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that exists ONLY in references/schema-registry.md, not in the
# SKILL.md body: the specific HTTP header used when registering a schema with
# Apicurio Registry to create-or-update (rather than always creating a new
# artifact). The body mentions Apicurio by name but contains no HTTP API
# details; the answer requires reading references/schema-registry.md.
smoke_test_skill "event-schema-design" \
  "What HTTP header is set when registering an event schema with Apicurio Registry to update an existing artifact rather than fail on re-registration?" \
  "X-Registry-IfExists"

smoke_test_summary
