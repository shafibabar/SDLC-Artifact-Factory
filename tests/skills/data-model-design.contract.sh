#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "data-model-design" \
  "In Kimball dimensional modeling, when a tracked dimension attribute changes and its history must be preserved, what does a Slowly Changing Dimension Type 2 do to the dimension table, and how does that differ from a Type 1 overwrite?" \
  "new dimension row"
smoke_test_summary
