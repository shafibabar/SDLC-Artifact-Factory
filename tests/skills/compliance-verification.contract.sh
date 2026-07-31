#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/control-gate-and-ccm.md: the change-management control the
# control gate enforces by comparing the PR author identity to the approving
# reviewer identity and failing the promotion when they are equal. This control
# (Separation of Duties, author != approver) appears ONLY in references/, never
# in the SKILL.md body.
smoke_test_skill "compliance-verification" \
  "The control gate enforces a change-management control by reading the pull request author identity and the approving reviewer identity and failing the promotion when they are equal, emitting an attestation of the check. What is that control called?" \
  "Separation of Duties"

smoke_test_summary
