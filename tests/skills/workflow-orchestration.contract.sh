#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the semantic-lock worked example from references/saga-isolation-countermeasures.md.
# The SKILL.md body summarizes the semantic lock and names the ONBOARDING_PENDING state,
# but the specific step that CLEARS the lock on success — the final retriable IndexDataAsset
# step — appears ONLY in the reference file (verify: `grep -i IndexDataAsset SKILL.md` is
# empty). A passing test proves the progressive-disclosure split works: the isolation-
# countermeasures reference is loaded and consulted, not just the body summary.
smoke_test_skill \
  "workflow-orchestration" \
  "In this skill's DataAsset semantic-lock example, the ONBOARDING_PENDING lock is set by the first compensatable step (RegisterDataAsset). Which later step clears that semantic lock on successful completion?" \
  "IndexDataAsset"

smoke_test_summary
