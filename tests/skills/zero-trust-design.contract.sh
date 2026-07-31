#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes a fact that lives ONLY in references/enforcement-and-mesh.md (loaded on
# demand), not in the SKILL.md body: the exact SPIFFE identity format Linkerd
# issues to bind a workload's mTLS certificate to its Kubernetes ServiceAccount.
smoke_test_skill \
  "zero-trust-design" \
  "In this plugin's Zero Trust design, Linkerd issues each workload a short-lived mTLS certificate tied to its Kubernetes ServiceAccount. What is the exact SPIFFE identity format used for that certificate?" \
  "spiffe://cluster.local"

smoke_test_summary
