#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the async env.py for asyncpg bridges Alembic's
# synchronous migration core onto the async connection via connection.run_sync().
# The SKILL.md body describes the bridge in prose but never names the run_sync call
# (grep-verified absent from the body) — only
# references/alembic-setup-and-revisions.md contains it. A correct answer proves the
# reference file was loaded, not just the body.
smoke_test_skill "python-migration" \
  "In the async Alembic env.py for asyncpg, which connection method is called to bridge Alembic's synchronous migration routine onto the async connection?" \
  "run_sync"

smoke_test_summary
