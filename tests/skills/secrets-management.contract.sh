#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "secrets-management" \
  "When a per-tenant Kubernetes cluster is replaceable, which GitOps secrets encryption tool does this skill recommend and why?" \
  "SOPS"

smoke_test_summary
