#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a non-obvious fact from the newly added Collector Deployment Topology section:
# When using DaemonSet Collector topology, the node IP must be injected via the Downward API
# using fieldPath: status.hostIP — not hardcoded or discovered by DNS.
smoke_test_skill "opentelemetry-instrumentation" \
  "When using DaemonSet Collector topology, how is the node IP injected into the pod so the SDK can reach the Collector?" \
  "status.hostIP"

smoke_test_summary
