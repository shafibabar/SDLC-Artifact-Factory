#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the exact MongoDB duplicate-key write-error
# code (11000) and the driver helper used to detect it. The SKILL.md body says
# a duplicate-key write becomes domain.ErrConflict but never states the code or
# the detection helper — those live only in references/repository-implementation.md.
smoke_test_skill "go-mongodb-repository" \
  "What MongoDB write-error code indicates a duplicate-key violation on a unique index, and which mongo-go-driver helper detects it?" \
  "11000"

smoke_test_summary
