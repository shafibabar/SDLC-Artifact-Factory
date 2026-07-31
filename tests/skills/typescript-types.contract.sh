#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the specific tsconfig flag beyond `strict`
# that makes array/index access return `T | undefined`. The SKILL.md body only
# says several flags "close a specific hole (unchecked index access, ...)" and
# points to references/boundary-and-strictness.md for the named settings — the
# flag name itself lives only in that reference file.
smoke_test_skill "typescript-types" \
  "Beyond \`strict: true\`, which tsconfig compiler flag makes indexed access like arr[i] typed as the element type OR undefined, forcing a presence check before use?" \
  "noUncheckedIndexedAccess"

smoke_test_summary
