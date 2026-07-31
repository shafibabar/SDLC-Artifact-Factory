#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact. The SKILL.md body names jsonschema and
# openapi-core as the validation libraries but never says how OpenAPI internal
# $refs get resolved. Only references/schema-contract-tests.md names the modern
# library jsonschema now requires for $ref resolution after RefResolver was
# deprecated (the referencing Registry) — proving the progressive-disclosure
# split is functional.
smoke_test_skill "python-contract-test" \
  "In the Python schema-based contract harness, which library does jsonschema now require to resolve the OpenAPI document's internal \$refs, after jsonschema.RefResolver was deprecated?" \
  "referencing"

smoke_test_summary
