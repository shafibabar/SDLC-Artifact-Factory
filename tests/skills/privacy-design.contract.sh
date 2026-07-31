#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "privacy-design" \
  "In Cavoukian's Privacy by Design, the fourth foundational principle (full functionality) is framed as which kind of trade-off relationship between privacy and utility?" \
  "positive-sum, not zero-sum"
smoke_test_summary
