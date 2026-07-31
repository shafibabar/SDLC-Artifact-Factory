#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a non-obvious fact from the newly added Standard 10 (local dev workflow):
# pullPolicy: Never is required when deploying a kind-loaded image — omitting it
# causes Kubernetes to attempt a registry pull that fails for :local tags.
smoke_test_skill "dockerfile-patterns" \
  "What image pull policy must be set in the Helm upgrade command when using kind load docker-image for local development, and why?" \
  "pullPolicy=Never"

smoke_test_summary
