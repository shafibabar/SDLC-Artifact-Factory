#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the newly added DX NFR: the production environment-provisioning SLO
# for the self-service InfrastructureRequest golden path. The skill body states
# "production | ≤ 30 minutes" — a specific threshold not guessable from the
# skill name or general IaC knowledge.
smoke_test_skill "opentofu-module" \
  "What is the environment-provisioning SLO target for a production InfrastructureRequest submitted via the self-service golden path?" \
  "30 min"

smoke_test_summary
