#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that lives ONLY in
# references/stakeholder-register-template.md: the CISO's stated concern in
# the filled Blocker Risk Register — that the product, by reading all of the
# customer's files, is itself the customer's biggest data risk. The SKILL.md
# body describes the CISO as a high-power/low-interest blocker but never
# states this specific concern. Answering requires the reference file.
smoke_test_skill "stakeholder-mapping" \
  "In the filled stakeholder register example, what specific concern does the CISO / IT Security blocker raise about the product itself in the Blocker Risk Register?" \
  "biggest data risk"

smoke_test_summary
