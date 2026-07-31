#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "kubernetes-workload-patterns" \
  "What restartPolicy value makes a container in initContainers behave as a native sidecar in Kubernetes 1.29+?" \
  "restartPolicy: Always"
smoke_test_summary
