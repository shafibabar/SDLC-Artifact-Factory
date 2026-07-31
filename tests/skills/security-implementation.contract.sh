#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/audit-and-evidence.md — the specific PostgreSQL mechanism that
# serializes concurrent per-tenant appends so the non-repudiation hash chain cannot
# fork. This detail lives ONLY in references/, not in SKILL.md's body (the body points
# to the reference for "hash-chain concurrency handling"), so a passing answer proves
# the progressive-disclosure split resolved.
smoke_test_skill "security-implementation" \
  "In the security audit log implementation, which specific PostgreSQL function is used to serialize concurrent per-tenant appends so two appends cannot read the same previous hash and fork the non-repudiation hash chain?" \
  "pg_advisory_xact_lock"

smoke_test_summary
