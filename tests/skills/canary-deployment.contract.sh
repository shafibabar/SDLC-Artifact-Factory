#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "canary-deployment" \
  "What Kubernetes CRD replaces a plain Deployment for services using progressive delivery with Argo Rollouts, and where in the Rollout spec are AnalysisTemplates attached?" \
  "analyses"
smoke_test_summary
