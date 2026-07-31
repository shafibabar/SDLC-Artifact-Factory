#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes references/viewtype-distinction.md: which C4 diagram is the
# component-and-connector view, and where deployment placement details
# (nodes, pods, replica counts) belong instead. The Container Diagram is a
# C&C view; deployment nodes/pods/replica counts belong on a separate
# deployment (allocation) view. "replica counts" appears only in
# references/, not in the SKILL.md body.
smoke_test_skill "container-diagram" \
  "The C4 Container diagram is a component-and-connector view. Name one specific placement detail that must NOT appear on it and instead belongs on the separate deployment (allocation) view." \
  "replica counts"
smoke_test_summary
