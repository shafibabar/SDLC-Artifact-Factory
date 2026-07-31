#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the worked strategic-roadmap example's "Explicitly Not On This
# Roadmap" section — specifically the rationale for excluding Data Loss
# Prevention (blocking/quarantine actions). The SKILL.md body teaches that a
# roadmap should name what is deliberately excluded and why, but the concrete
# exclusion list and its reasoning ("enforcement is a different product with
# different failure modes and buyer expectations") live only in
# references/roadmap-template.md.
smoke_test_skill "roadmap-authoring" \
  "In the worked strategic-roadmap example, the 'Explicitly Not On This Roadmap' section deliberately excludes Data Loss Prevention (blocking/quarantine actions). What is the stated reason it is left off the roadmap?" \
  "different product"

smoke_test_summary
