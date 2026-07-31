#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/boundary-mapping.md-only fact: the machine-readable
# error code the single transport-edge exception handler assigns to an
# OptimisticConcurrencyError. The SKILL.md body names the exception and the
# "catch once at the edge" rule but deliberately does NOT carry the kind->code
# mapping (grep-verified absent from the body) — that table lives only in
# references/boundary-mapping.md. Answering "version_conflict" proves the
# progressive-disclosure split loads the reference, not just the body.
smoke_test_skill "python-error-handling" \
  "In the transport-edge error envelope, what machine-readable error code (the 'code' field) does the boundary exception handler assign to an OptimisticConcurrencyError raised by a version-CAS conflict?" \
  "version_conflict"

smoke_test_summary
