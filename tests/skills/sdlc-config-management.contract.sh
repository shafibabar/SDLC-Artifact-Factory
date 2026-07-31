#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the optional_database entry under
# tech_stack_overrides is a structured object (not a plain string like every
# other override row) with three required sub-fields. The body names
# optional_database but does not enumerate its sub-fields — only
# references/config-field-reference.md does.
smoke_test_skill "sdlc-config-management" \
  "In sdlc-config.json, the optional_database entry under tech_stack_overrides is a structured object rather than a plain string. What three sub-fields does it require?" \
  "included"

smoke_test_summary
