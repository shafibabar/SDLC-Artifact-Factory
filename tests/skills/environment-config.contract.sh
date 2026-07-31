#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Body fact: projected volume pattern (SKILL.md body).
smoke_test_skill "environment-config" \
  "What Kubernetes volume type does the environment-config skill recommend for combining ConfigMap, Secret, and serviceAccountToken into a single mount path?" \
  "projected"

# references/-only fact (cloud-environments.md): each cloud's KMS protects
# Vault's UNSEAL key so no static unseal key is stored. The term "auto-unseal"
# appears only in references/cloud-environments.md, never in the SKILL.md body,
# proving the multi-cloud reference is reachable via progressive disclosure.
smoke_test_skill "environment-config" \
  "In the environment-config skill's multi-cloud provisioning guidance, what Vault capability does each cloud's KMS (AWS KMS / Azure Key Vault / Cloud KMS) protect the unseal key for, so that no static unseal key is stored?" \
  "auto-unseal"

smoke_test_summary
