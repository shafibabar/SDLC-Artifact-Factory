#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "environment-config" \
  "What Kubernetes volume type does the environment-config skill recommend for combining ConfigMap, Secret, and serviceAccountToken into a single mount path?" \
  "projected"

smoke_test_summary
