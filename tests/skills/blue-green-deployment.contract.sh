#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a non-obvious fact added during the #477 refactor:
# the postPromotionAnalysis field triggers automatic rollback when it fails,
# which is the GitOps-native alternative to a manual selector-revert PR.
smoke_test_skill "blue-green-deployment" \
  "What does postPromotionAnalysis do when its AnalysisTemplate fails after a blue-green promotion?" \
  "automatic rollback"

smoke_test_summary
