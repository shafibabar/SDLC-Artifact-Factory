#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the newly added native sidecar API fact: Kubernetes 1.29+ treats an
# initContainer entry with restartPolicy: Always as a native sidecar. This is
# non-obvious (init containers normally run to completion and exit) and appears
# verbatim in the skill body.
smoke_test_skill "kubernetes-manifest" \
  "What restartPolicy value in an initContainers entry makes Kubernetes 1.29+ treat a container as a native sidecar that stays running?" \
  "Always"

smoke_test_summary
