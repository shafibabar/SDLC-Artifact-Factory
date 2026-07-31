# Alembic Setup, Async `env.py`, and a Worked Hand-Written Revision

Reference for `python-migration`. Everything here assumes Alembic is used **as a
migration runner over hand-written SQL** — no SQLAlchemy ORM models, no
`--autogenerate`. Copy the `env.py` verbatim; adapt the revision template per change.

---

## 1. Install and initialise

Alembic and the async driver are separate installs. `asyncpg` is the driver; Alembic's
async `env.py` drives it through SQLAlchemy's async *engine* wrapper only (the engine,
not the ORM — no declarative models are ever imported).

```bash
uv add alembic sqlalchemy asyncpg     # sqlalchemy supplies the async engine wrapper only
alembic init -t async migrations      # the built-in async template scaffolds an asyncio env.py
```

`alembic init -t async` is important: the default (sync) template writes a synchronous
`env.py` that cannot drive `asyncpg`. The `-t async` template gives the asyncio skeleton
this reference then hardens for hand-written-SQL use.

Resulting layout:

```
alembic.ini                     # script_location + logging; NO connection secret in git
migrations/
  env.py                        # the async bridge (Section 3)
  script.py.mako                # revision template (Section 4 trims it)
  versions/
    0001_create_data_assets.py
    0002_add_classification_status.py
```

---

## 2. `alembic.ini` — no secret in the repo

Keep the DSN out of version control. Leave `sqlalchemy.url` blank in `alembic.ini` and
inject it from the environment inside `env.py`, so the same image migrates any tenant
database by swapping one env var.

```ini
# alembic.ini (trimmed)
[alembic]
script_location = migrations
# sqlalchemy.url is intentionally blank — env.py reads DATABASE_URL at runtime.
prepend_sys_path = .

[loggers]
keys = root,sqlalchemy,alembic
```

The DSN uses the async dialect prefix so SQLAlchemy selects the asyncpg driver:

```
DATABASE_URL=postgresql+asyncpg://app:secret@postgres:5432/tenant_acme
```

---

## 3. The async `env.py` — bridging asyncpg into Alembic's sync core

Alembic's migration execution (`context.run_migrations()`) is **synchronous**. `asyncpg`
has no synchronous mode. The bridge: open an async engine, `await` a connection, then
hand that live connection to Alembic's synchronous routine through
`connection.run_sync(...)`. `run_sync` runs a *sync-signature* callable
(`do_run_migrations`) on the greenlet-backed sync facade of the async connection — this
is the one line that makes an async driver drivable by a sync migration engine, and it
is the single most-copied, most-mistyped part of an async Alembic setup.

```python
# migrations/env.py
import asyncio
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

config = context.config

# Inject the DSN from the environment (never committed to alembic.ini).
config.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# No target_metadata: we do NOT autogenerate. Hand-written SQL revisions only.
target_metadata = None


def do_run_migrations(connection: Connection) -> None:
    """Runs inside Alembic's synchronous context. `connection` is the sync
    facade handed over by run_sync() below."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        # One transaction wraps each revision. autocommit_block() opens an
        # escape hatch for CREATE INDEX CONCURRENTLY (see Section 5).
        transaction_per_migration=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Open the asyncpg-backed engine and bridge it into the sync migration run."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,   # a migration Job is short-lived; no pool to keep warm
    )

    async with connectable.connect() as connection:
        # THE BRIDGE: run the sync-signature do_run_migrations on the async
        # connection's sync facade. This is what lets Alembic's synchronous
        # core drive an asyncpg connection.
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


# Offline mode (--sql) is unused here: we run against a live DB in a K8s Job.
run_migrations_online()
```

Key points a reviewer checks:

- `target_metadata = None` — proof no ORM metadata is wired in; autogenerate is inert.
- `connection.run_sync(do_run_migrations)` — the async→sync bridge; its absence (or a
  naive `context.run_migrations()` called directly on the async connection) is the
  classic "coroutine was never awaited" / "connection is not bound" failure.
- `NullPool` — a one-shot migration Job should not hold a connection pool open.

---

## 4. A worked hand-written revision (create + a second additive change)

`script.py.mako` generates a stub with `upgrade()`/`downgrade()`. Fill them with
`op.execute()` raw SQL. No `sa.Column`, no `op.create_table` DSL — the SQL is the
artifact, matching `go-migration`'s embedded-SQL philosophy.

Generate with a pinned, sortable id:

```bash
alembic revision --rev-id 0001 -m "create data_assets"
```

```python
# migrations/versions/0001_create_data_assets.py
"""create data_assets

Revision ID: 0001
Revises:
Create Date: 2026-07-31
"""
from alembic import op

revision = "0001"
down_revision = None          # first revision — head of the down_revision chain
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE data_assets (
            id           UUID PRIMARY KEY,
            tenant_id    UUID NOT NULL,
            source       TEXT NOT NULL,
            display_name TEXT NOT NULL,
            version      BIGINT NOT NULL DEFAULT 1,
            created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
            deleted_at   TIMESTAMPTZ
        )
        """
    )


def downgrade() -> None:
    op.execute("DROP TABLE data_assets")
```

The second revision chains off the first via `down_revision`:

```python
# migrations/versions/0002_add_classification_status.py
"""add classification_status (nullable, additive — safe in one deploy)

Revision ID: 0002
Revises: 0001
"""
from alembic import op

revision = "0002"
down_revision = "0001"        # THIS is where ordering lives — not the filename
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Nullable + additive: tolerated by both old and new application code.
    op.execute("ALTER TABLE data_assets ADD COLUMN classification_status TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE data_assets DROP COLUMN classification_status")
```

`down_revision = "0001"` is the honest divergence from goose to internalise: **the
`down_revision` pointer, not the filename, defines order.** The `--rev-id 0001`/`0002`
convention keeps filenames sortable for humans, but Alembic itself walks the chain.

---

## 5. `CREATE INDEX CONCURRENTLY` inside `autocommit_block()`

Because `env.py` sets `transaction_per_migration=True`, each revision runs in a
transaction — and `CREATE INDEX CONCURRENTLY` is rejected inside one. Open an
autocommit escape hatch for exactly that statement:

```python
# migrations/versions/0003_index_tenant_sensitivity.py
from alembic import op

revision = "0003"
down_revision = "0002"


def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute(
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS "
            "idx_data_assets_tenant_sensitivity "
            "ON data_assets (tenant_id, classification_status) "
            "WHERE deleted_at IS NULL"
        )


def downgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute("DROP INDEX CONCURRENTLY IF EXISTS idx_data_assets_tenant_sensitivity")
```

---

## 6. The apply command — CI round-trip and the deploy Job

**CI round-trip** (proves `downgrade()` actually works, against a real Postgres from
`testcontainers-python`):

```bash
# Makefile target: migrate-test
DATABASE_URL=$(TEST_DSN) alembic upgrade head
DATABASE_URL=$(TEST_DSN) alembic downgrade -1
DATABASE_URL=$(TEST_DSN) alembic upgrade head
```

**Makefile forward-apply** used both locally and by the deploy Job:

```makefile
migrate:            ## apply all pending revisions to $DATABASE_URL
	alembic upgrade head

migrate-status:     ## show current revision vs head
	alembic current
	alembic heads      # MUST print a single head — multiple = unmerged divergence
```

**Kubernetes pre-deploy Job** — migrations run to completion *before* the rolling
update, never from the app's request path:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-assets-migrate
spec:
  backoffLimit: 0                 # a failed migration must abort the deploy, not retry blindly
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: registry/data-assets:{{ .Values.image.tag }}
          command: ["alembic", "upgrade", "head"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: data-assets-db
                  key: dsn
```

A Helm `pre-install`/`pre-upgrade` hook annotation on this Job sequences it ahead of the
Deployment rollout. If `alembic upgrade head` exits non-zero, the Job fails, the hook
fails, and the release is aborted before any new pod serves traffic.

---

## 7. Checklist

- [ ] `alembic init -t async` (not the sync default) — asyncpg cannot use a sync `env.py`.
- [ ] `target_metadata = None` — no ORM, autogenerate inert.
- [ ] `connection.run_sync(do_run_migrations)` present — the async→sync bridge.
- [ ] DSN injected from `DATABASE_URL`; `alembic.ini` holds no secret.
- [ ] Every revision uses `op.execute("...SQL...")`, `--rev-id` pins a sortable id.
- [ ] `alembic heads` prints exactly one head before merge.
- [ ] CI runs `upgrade → downgrade -1 → upgrade`.
- [ ] Production applies via a pre-rollout K8s Job with `backoffLimit: 0`.
