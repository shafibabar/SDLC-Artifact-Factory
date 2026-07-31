#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/asyncpg-adapter.md-only fact: the specific PostgreSQL
# SQLSTATE that the asyncpg adapter's error-translation maps to an
# already-exists domain error. The SKILL.md body names asyncpg error
# translation in prose but carries no SQLSTATE codes at all (verified absent);
# only references/asyncpg-adapter.md's translation table gives 23505 for a
# unique/primary-key violation -> AlreadyExistsError. A pass proves the
# progressive-disclosure split loaded the reference, not just the body.
smoke_test_skill "python-repository-pattern" \
  "In the asyncpg adapter's error-translation, which PostgreSQL SQLSTATE code is raised by a unique or primary-key violation that gets mapped to an already-exists domain error?" \
  "23505"

smoke_test_summary
