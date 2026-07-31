#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that lives ONLY in references/frd-template.md (the worked FRD
# example), not in the SKILL.md body: REQ-010 classifies each data asset into
# one of four named sensitivity levels. The SKILL.md body discusses
# classification abstractly but never enumerates the four levels — that concrete
# taxonomy exists only in the reference. Proves the progressive-disclosure split
# is functional.
smoke_test_skill "requirements-analysis" \
  "In the worked Functional Requirements Document example, what four sensitivity levels does the system classify each data asset into?" \
  "Confidential / Restricted"

smoke_test_summary
