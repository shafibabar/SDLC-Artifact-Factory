#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the DX NFR in the skill body: the production environment-provisioning
# SLO for the self-service InfrastructureRequest golden path. The body states
# "production | ≤ 30 minutes" — a specific threshold not guessable from the
# skill name or general IaC knowledge.
smoke_test_skill "opentofu-module" \
  "What is the environment-provisioning SLO target for a production InfrastructureRequest submitted via the self-service golden path?" \
  "30 min"

# Probes a references/-only multi-cloud fact (references/cloud-provider-modules.md,
# §Managed PostgreSQL): the concrete OpenTofu resource type that provisions managed
# PostgreSQL on Azure. This exact resource name lives only in the reference file, not
# in the SKILL.md body — proving the multi-cloud provider reference is loaded on demand.
smoke_test_skill "opentofu-module" \
  "When a product deployment targets Azure, which OpenTofu resource type does the module use to provision managed PostgreSQL?" \
  "azurerm_postgresql_flexible_server"

smoke_test_summary
