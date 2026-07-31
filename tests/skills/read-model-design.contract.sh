#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "read-model-design" \
  "What is the name of the Go struct the skill recommends for holding list filter parameters to prevent SQL injection in a Read Model query?" \
  "DataAssetListFilter"

smoke_test_summary
