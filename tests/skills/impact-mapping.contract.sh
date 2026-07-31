#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "impact-mapping" \
  "In an impact map, why are the WHAT-level deliverables treated as droppable hypotheses — how certain is the deliverables level compared with the other three levels?" \
  "most uncertain"
smoke_test_summary
