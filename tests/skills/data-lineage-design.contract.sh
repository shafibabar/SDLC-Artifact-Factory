#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/granularity-and-capture.md: the OpenLineage event model's
# dataset facet that carries field-to-field (column-level) lineage mappings.
# The SKILL.md body describes field-level lineage but deliberately does NOT
# name the facet — the facet name lives only in references/, so a correct
# answer requires the reference file to have been loaded.
smoke_test_skill "data-lineage-design" \
  "In the OpenLineage event model this skill uses, what is the name of the dataset facet that carries column-level (field-to-field) lineage mappings?" \
  "columnLineage"

smoke_test_summary
