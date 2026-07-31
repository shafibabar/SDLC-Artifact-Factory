#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "helm-chart" \
  "What workloadType value should be set in values.yaml when deploying an OTel Collector that must run on every Kubernetes node?" \
  "DaemonSet"

smoke_test_summary
