#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "data-pipeline-implementation" \
  "When a pipeline stage worker retries a transient failure with exponential backoff, why is jitter added to the delay — what specific problem across many workers does it prevent?" \
  "thundering herd"
smoke_test_summary
