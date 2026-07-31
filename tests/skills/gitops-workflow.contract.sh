#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Non-obvious fact: the skill specifies that SOPS is preferred over Sealed Secrets
# when the cluster is ephemeral (replaceable), because Sealed Secrets couples
# decryption to the cluster's private key, making cluster recreation a key
# management problem. The specific criterion "cluster is replaceable" / "ephemeral"
# drives the SOPS decision.
smoke_test_skill "gitops-workflow" \
  "When should you choose SOPS over Sealed Secrets for GitOps secrets management?" \
  "cluster is replaceable"

smoke_test_summary
