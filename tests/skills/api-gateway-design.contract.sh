#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# References-only probe: the SKILL.md body names DB-less mode as the stateless-edge
# default but does NOT give the concrete configuration that turns off Kong's
# control-plane database. That env setting (KONG_DATABASE=off) lives only in
# references/kong-configuration.md. Answering it proves the progressive-disclosure
# split is functional — the body pointer resolves to the reference content.
smoke_test_skill "api-gateway-design" \
  "In Kong DB-less mode, what configuration setting turns off the control-plane database?" \
  "KONG_DATABASE=off"

smoke_test_summary
