# Toxiproxy Fault Injection in pytest

Full standard referenced from `SKILL.md`'s "Fault Mechanisms" section.
Self-contained — reads without the parent body already in context. Covers
running toxiproxy as a testcontainers Docker container, driving it with the
`toxiproxy-python` client, wiring the application's DSN through the proxy,
guaranteeing toxic cleanup, and two full worked experiments. Every experiment
here carries the four-part header from `references/experiment-design.md`.

---

## Why a Proxy Between the App and Its Dependency

Toxiproxy (Shopify, open-source, Apache-2.0) is a TCP proxy that sits between
the service and a dependency it dials. The service is pointed at the proxy's
**listen** address instead of the real dependency; toxiproxy forwards to the
real **upstream** and injects **toxics** — latency, a full stop, a reset — onto
that forwarded connection. The fault is genuinely on the wire, so it exercises
the socket-level failure path (a dead connection, a hung read) that an app-level
mock cannot reach. Toxics are added and removed over toxiproxy's HTTP control
API on port `8474`, which the `toxiproxy-python` client wraps.

`toxiproxy-python` is the real PyPI package; its import name is `toxiproxy`.
Install it and the container library into the chaos test extra:

```
pip install toxiproxy-python testcontainers[postgres] aiokafka asyncpg pytest pytest-asyncio
```

---

## Running Toxiproxy as a testcontainers Container

testcontainers-python has no dedicated toxiproxy module, so run the official
image through the generic `DockerContainer`, exposing the control port `8474`
and one listen port per proxied dependency. The Postgres and Redpanda
containers come up first (see `python-integration-test` for their session
fixtures); toxiproxy is told their in-Docker upstream addresses.

```python
# tests/chaos/conftest.py
import socket
from dataclasses import dataclass

import pytest
import pytest_asyncio
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs
from testcontainers.postgres import PostgresContainer
from toxiproxy import Toxiproxy

TOXIPROXY_IMAGE = "ghcr.io/shopify/toxiproxy:2.9.0"
PG_LISTEN_PORT = 15432          # toxiproxy's proxied port for Postgres, inside the toxiproxy container


@dataclass
class ChaosStack:
    pg_dsn: str                 # points AT toxiproxy, not the real Postgres
    toxiproxy: Toxiproxy
    pg_proxy: object            # toxiproxy Proxy handle for the Postgres link


def _free_host_port() -> int:
    s = socket.socket()
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    return port


@pytest_asyncio.fixture
async def chaos_stack():
    # Real Postgres first — its own session fixture normally runs alembic upgrade head.
    with PostgresContainer("postgres:16-alpine") as pg:
        pg_net_alias = pg.get_wrapped_container().attrs["Config"]["Hostname"]

        host_ctrl = _free_host_port()
        host_pg = _free_host_port()
        toxi = (
            DockerContainer(TOXIPROXY_IMAGE)
            .with_bind_ports(8474, host_ctrl)          # control API
            .with_bind_ports(PG_LISTEN_PORT, host_pg)  # proxied Postgres link
        )
        toxi.start()
        try:
            wait_for_logs(toxi, "Starting Toxiproxy")

            client = Toxiproxy()
            client.update_api_consumer("localhost", host_ctrl)  # talk to the mapped control port

            # Proxy listens on 0.0.0.0:15432 inside its own container and forwards
            # to the Postgres container's in-Docker address.
            pg_proxy = client.create(
                name="postgres",
                listen=f"0.0.0.0:{PG_LISTEN_PORT}",
                upstream=f"{pg_net_alias}:5432",
                enabled=True,
            )

            # The app connects THROUGH toxiproxy: host side of the proxied port.
            dsn = (
                f"postgresql://{pg.username}:{pg.password}"
                f"@localhost:{host_pg}/{pg.dbname}"
            )
            yield ChaosStack(pg_dsn=dsn, toxiproxy=client, pg_proxy=pg_proxy)
        finally:
            client.destroy_all()   # remove every proxy + toxic, always
            toxi.stop()
```

`destroy_all()` in the `finally` is the outer guarantee: even if a test forgets
its own cleanup, no toxic or proxy survives the fixture. Individual toxics still
get a per-test finalizer below — belt and suspenders, because a toxic leaked
into a shared proxy poisons every later test in the same run.

---

## The Toxic Types This Repo Uses

Toxiproxy toxics are directional (`upstream` = data toward the dependency,
`downstream` = data back to the app) and carry a `toxicity` (0.0–1.0 fraction
of connections affected). The three this repo's experiments need:

| Intent | Toxic `type` | Key attribute | Models |
|---|---|---|---|
| Added latency | `latency` | `latency` (ms), `jitter` (ms) | A slow-but-alive dependency |
| Stall then drop | `timeout` | `timeout` (ms; `0` = never send data, hold the connection open) | A dependency that accepts the connection then never answers |
| Hard partition | `reset_peer` | `timeout` (ms before the TCP RST) | A severed link — the peer vanishes and the socket is reset |

`reset_peer` is the toxic that produces a **true network partition**: it sends a
TCP RST rather than merely delaying bytes, so the application sees a
connection-reset error exactly as it would when a link is severed beneath it.
`latency` and `timeout` alone keep the socket alive; only `reset_peer` (or
disabling the proxy with `proxy.disable()`) actually breaks the connection. Use
`reset_peer` when the hypothesis is "the link is severed", `timeout` when it is
"the dependency hangs", and `latency` when it is "the dependency is slow".

A guaranteed-cleanup helper every experiment uses:

```python
from contextlib import contextmanager

@contextmanager
def apply_toxic(proxy, *, name, type, attributes, stream="downstream", toxicity=1.0):
    toxic = proxy.add_toxic(
        name=name, type=type, stream=stream, toxicity=toxicity, attributes=attributes
    )
    try:
        yield toxic
    finally:
        proxy.destroy_toxic(name)   # removed on both the pass and the failure path
```

---

## Worked Experiment 1 — Sever Postgres, Circuit Breaker Opens

The service guards its repository/downstream call with a Circuit Breaker (an
async breaker such as `purgatory` or `aiobreaker`, or the app's own). The
hypothesis: a severed DB link trips the breaker within its threshold and calls
fail fast with `ServiceUnavailableError` — they do **not** hang on a dead
socket — and the breaker closes again once the link heals.

```python
# tests/chaos/test_breaker_severed_db.py
import time
import pytest

from app.errors import ServiceUnavailableError
from app.service import classify           # guarded by the Circuit Breaker
from tests.chaos.conftest import apply_toxic
from tests.chaos.poll import poll_until    # async deadline-bounded poll helper

pytestmark = [pytest.mark.chaos, pytest.mark.asyncio]


# EXPERIMENT:   Circuit Breaker opens when the Postgres link is severed
# STEADY STATE: classify() returns < 0.8s, error rate < 0.1% (measured pre-fault)
# HYPOTHESIS:   a severed DB link trips the breaker within 5s; calls fail fast
#               with ServiceUnavailableError, never hang on a dead socket
# BLAST RADIUS: one tenant's ephemeral stack, Postgres link only
# ROLLBACK:     abort if the fault window exceeds 60s (guarded by the deadline)
async def test_breaker_opens_on_severed_db_link(chaos_stack, app_client):
    # 1. Steady state — a healthy call is fast and succeeds.
    t0 = time.monotonic()
    await classify(app_client, tenant_id="chaos-tenant", sample="doc-1")
    assert time.monotonic() - t0 < 0.8

    # 2. Inject — sever the link with reset_peer (a TCP RST, not mere latency).
    with apply_toxic(
        chaos_stack.pg_proxy,
        name="sever",
        type="reset_peer",
        attributes={"timeout": 0},      # reset immediately
    ):
        # 3. Observe — the breaker opens; calls fail FAST, they do not hang.
        start = time.monotonic()
        with pytest.raises(ServiceUnavailableError):
            await classify(app_client, tenant_id="chaos-tenant", sample="doc-2")
        assert time.monotonic() - start < 1.0    # fail-fast, not a socket-timeout hang

    # 4. Conclude — link healed (toxic destroyed); the breaker half-opens and closes.
    async def healthy_again() -> bool:
        try:
            await classify(app_client, tenant_id="chaos-tenant", sample="doc-3")
            return True
        except ServiceUnavailableError:
            return False

    assert await poll_until(healthy_again, timeout=30.0), "breaker never re-closed"
```

The two assertions that make this a real experiment are **fail-fast** (elapsed
< 1s while the link is dead, proving the breaker short-circuited instead of the
call hanging on the dead socket) and **recover** (the poll succeeds within 30s
after the fault clears). Asserting only the failure would be half an experiment.

---

## Worked Experiment 2 — Kill a Redpanda Broker, Consumer Recovers With No Data Loss

A wire toxic cannot model a broker **process** dying and coming back — that is a
testcontainers job. Kill the Redpanda container, publish while it is down (the
outbox relay must retain the row, `python-event-publisher`), restart it, and
assert the consumer resumes from its **committed offset** and the effect lands
exactly once, with **no data loss**.

```python
# tests/chaos/test_consumer_broker_kill.py
import pytest
from tests.chaos.poll import poll_until

pytestmark = [pytest.mark.chaos, pytest.mark.asyncio]


# EXPERIMENT:   consumer resumes and loses nothing across a broker kill/restart
# STEADY STATE: consumer lag ~0; a published event is processed within 2s
# HYPOTHESIS:   with the broker dead, the outbox retains the row (no loss) and
#               the consumer's fetch retries with backoff; on restart the
#               consumer resumes from its last committed offset and the effect
#               is applied exactly once
# BLAST RADIUS: one tenant's ephemeral stack, the single Redpanda broker
# ROLLBACK:     abort if the outbox row is lost, or lag fails to drain within 60s
async def test_consumer_recovers_from_broker_kill(chaos_stack, redpanda, outbox, projection):
    # 1. Steady state — a normal publish lands in the projection quickly.
    await outbox.enqueue(tenant_id="chaos-tenant", event="DataAssetClassified", key="a-1")
    assert await poll_until(lambda: projection.has("a-1"), timeout=2.0)

    # 2. Inject — kill the broker process (SIGKILL at the Docker layer).
    redpanda.get_wrapped_container().kill()

    # 3. Observe — publish while the broker is dead: the row must SURVIVE, not vanish.
    await outbox.enqueue(tenant_id="chaos-tenant", event="DataAssetClassified", key="a-2")
    assert await outbox.unpublished_count() >= 1, "outbox dropped a row during outage — data loss"

    # 4. Recover — restart the broker; consumer resumes from its committed offset.
    redpanda.get_wrapped_container().restart()
    assert await poll_until(lambda: projection.has("a-2"), timeout=60.0), "consumer never resumed"

    # Exactly-once: redelivering a-1 (already processed) must NOT double-apply.
    await redpanda.redeliver("a-1")
    assert projection.count("a-1") == 1, "idempotency broke under redelivery"
```

The pass condition is **recovery, not just survival**: the outbox row present
during the outage proves no loss, and `projection.has("a-2")` after restart
proves the consumer resumed from its committed offset rather than skipping the
gap. The redelivery check proves `Idempotency` held across the disruption.

---

## Cleanup Discipline

- Every `add_toxic` goes through `apply_toxic` so its `destroy_toxic` runs on
  both the pass and the failure path — a `try/except` that swallows an assertion
  must never skip toxic removal.
- The fixture's `finally` calls `destroy_all()` as the outer net; container
  teardown (`with PostgresContainer(...)`, `toxi.stop()`) reverts every
  Docker-level fault including a killed-then-restarted broker.
- No experiment uses `asyncio.sleep` to wait for recovery: `poll_until` bounds
  every wait with a deadline, so the test is fast when the system is fast and
  fails with a message when it is not.
