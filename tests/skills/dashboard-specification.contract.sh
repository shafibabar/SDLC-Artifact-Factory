#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/chart-selection-guide.md — the Knaflic chart-type prescription
# for comparing one metric across categories at two points in time. This fact lives
# only in references/, not in SKILL.md's body (verified: "slopegraph" does not appear
# in the body's quick-selection table).
smoke_test_skill "dashboard-specification" \
  "Per the chart-selection guide, which chart type does Knaflic prescribe for comparing one metric across several categories at two points in time (e.g. coverage per Bounded Context this quarter vs last)?" \
  "slopegraph"

smoke_test_summary
