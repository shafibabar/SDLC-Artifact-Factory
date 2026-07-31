#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/exploratory-charter-link.md: the named exploratory-testing
# heuristic (Hendrickson) that is highest-yield for state-management bugs a
# scripted UAT scenario cannot reach — a fact absent from SKILL.md's body,
# which points at but does not enumerate the heuristics.
smoke_test_skill "uat-scenario" \
  "When a scripted UAT scenario set is complemented by an exploratory charter, which named exploratory-testing heuristic is highest-yield for finding state-management bugs that scripted scenarios structurally cannot reach?" \
  "Interruption"

smoke_test_summary
