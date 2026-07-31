#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: asyncpg's per-connection prepared-statement
# cache is incompatible with a transaction-mode connection pooler (PgBouncer in
# `transaction` mode), so statement_cache_size must be set to 0 there. This
# caveat lives ONLY in references/optimization-patterns.md (the asyncpg
# pool-tuning section) — the SKILL.md body never names PgBouncer or
# statement_cache_size at all (grep-verified absent), so a correct answer proves
# the progressive-disclosure split into references/ is functional.
smoke_test_skill "python-performance-optimization" \
  "In this repo's Python performance guidance, when the service sits behind a transaction-mode connection pooler such as PgBouncer, what must asyncpg's statement_cache_size be set to, and why?" \
  "statement_cache_size=0"

smoke_test_summary
