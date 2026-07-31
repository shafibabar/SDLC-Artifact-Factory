#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
smoke_test_skill "context-map-patterns" \
  "What is the specific named check or test that this skill uses to decide between Conformist and Anti-Corruption Layer when the upstream is non-cooperative — and what does it examine?" \
  "Ubiquitous Language collision check"
smoke_test_summary
