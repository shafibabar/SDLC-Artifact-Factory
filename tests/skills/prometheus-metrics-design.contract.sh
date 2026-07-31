#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/cardinality-and-histograms.md: the worst-case active-series
# arithmetic for pipeline_documents_processed_total (3 services x 2 source_type
# x 3 document_type x 3 outcome = 54 series). The SKILL.md body states the
# cardinality-budget rule but deliberately omits this worked calculation, so a
# correct "54" answer can only come from the references file.
smoke_test_skill "prometheus-metrics-design" \
  "What is the worst-case active time-series count for the pipeline_documents_processed_total metric given its allowed labels, and how is that number derived?" \
  "54"

smoke_test_summary
