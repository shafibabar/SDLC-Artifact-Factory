#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes the term lifecycle detail that lives only in
# references/ul-discovery-and-curation.md (Section 4.3) — the body names the
# lifecycle and points to the reference, but never states what to do with a
# term that leaves the domain. The reference says: move it to a "retired
# terms" section rather than deleting it, so the record explains its absence
# and prevents re-introduction.
smoke_test_skill "ubiquitous-language" \
  "When a Ubiquitous Language term is no longer part of the domain, what should be done with it instead of deleting it outright, and why?" \
  "retired terms"

smoke_test_summary
