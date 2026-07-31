# Flake Control and Scope — Keeping the E2E Suite Stable and Small

E2E tests cross real network hops, real DNS resolution, real Linkerd mTLS
handshakes, and real asynchronous pipeline lag — dependencies a unit test never
touches and an integration test only partially touches (testcontainers is real,
but still in-process and single-host). Some non-zero flake rate is the honest
cost of that realism, not evidence of a badly written test. The discipline is not
eliminating flakiness to zero — it is budgeting for it mechanically, so a flaky
test is a tracked, time-boxed liability instead of a build everyone learns to
re-run and ignore. This file covers the retry policy, quarantine, the timeout and
data-isolation mechanics that keep tests deterministic, how to choose the minimal
critical-path set, and where the suite runs in CI.

---

## Retry Policy — One Automatic Retry, Then a Verdict

A failing journey test is retried **exactly once**, automatically, before it is
recorded as a genuine failure. The Python mechanism is the **pytest-rerunfailures**
plugin, bounded to a single rerun:

```bash
# The full-suite CI invocation — one rerun, and only for tests that actually failed.
pytest tests/e2e -m "e2e and not quarantine" \
  --reruns 1 --only-rerun "" \
  -p no:cacheprovider -v
```

`--reruns 1` caps the retry at exactly one extra attempt; there is no third try.
A test that fails on both the first attempt and the rerun is a genuine failure —
it blocks the build, exactly as any other CI failure would. A test that fails
once and passes on the rerun is, by definition, **flaky**: this is the mechanical
detection rule, not a judgment call left to whoever is looking at the build. Pin
the exception classes the rerun is allowed to apply to with `--only-rerun` in a
real config so a genuine assertion error is never silently reattempted; the empty
pattern above is the illustrative "rerun any failure once" default.

**This is not "retry until green."** The policy is bounded at exactly one rerun,
and the automatic retry is never used to paper over a test already flagged flaky.
Retry-until-green as a standing practice would hide the real intermittent bugs
(races, ordering assumptions, resource exhaustion under load) that e2e exists to
catch — the whole point of running against the real deployed system is to surface
exactly this class of bug, and unlimited retries erase the signal.

**Honest divergence from Go.** `go-e2e-test` implements the one-retry policy by
re-invoking `go test -run` with the failed test names parsed out of a JSON run
log; Python gets the same policy for free from `pytest-rerunfailures`' `--reruns`
flag, no re-invocation script needed — a mechanical difference, identical
governance.

---

## Detection — Recorded, Not Assumed

Every fail-then-pass-on-rerun pair is logged with enough context to act on later,
not silently absorbed by the green build. `pytest-rerunfailures` surfaces reruns
in the report; capture them alongside the trace id the failing attempt produced:

```json
{"test": "test_ingest_classify_then_appears_in_compliance_report",
 "run_id": "1892...", "attempt_1": "FAIL", "attempt_2": "PASS",
 "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736", "timestamp": "..."}
```

The `trace_id` ties directly into the OpenTelemetry span the failing attempt
produced (`e2e-setup-and-flow.md`'s trace-correlation helper) — a flake
investigation starts from a concrete trace, not a re-run under a debugger hoping
to reproduce it. A simple append-only log of these records answers the question
that decides quarantine: has this specific test flaked more than once across
recent runs?

---

## Quarantine — Move, Don't Delete, Don't Silently Skip

A test that has flaked (fail-then-pass-on-rerun) more than once across recent
runs graduates to quarantine. In Python this is a **marker**, not a separate build
tag — the test body is unchanged, only its marker moves:

```python
@pytest.mark.e2e
@pytest.mark.quarantine   # flaked 3x in the last 10 nightly runs — projection lag beyond the wait deadline
@pytest.mark.asyncio
async def test_bulk_classify_under_load(client, run_id):
    # Tracking: https://github.com/org/repo/issues/1234 — opened 2026-07-20, deadline 2026-08-03
    ...   # unchanged test body — quarantine is a marker move, not a rewrite
```

```yaml
# Quarantined journeys run, but cannot fail the required gate.
- name: Quarantined journeys (non-blocking)
  continue-on-error: true
  run: pytest tests/e2e -m "quarantine" -v
```

The required gate runs `-m "e2e and not quarantine"`; the quarantine job runs
`-m "quarantine"` with `continue-on-error: true`. Every quarantined test carries,
in the same commit that quarantines it: a **tracked issue** (opened the day of
quarantine) and a **two-week deadline**. Before the deadline, exactly one of two
things happens:

1. **Fix the root cause**, using the trace id(s) from detection to find the span
   that broke (a wait deadline too tight for real pipeline lag, connection-pool
   exhaustion under the `kind` cluster's smaller footprint, etc.), then remove the
   `quarantine` marker in the same PR that fixes it.
2. **Delete it deliberately**, with the issue documenting that this journey's
   coverage is better provided at a lower layer (decomposed into something
   `python-unit-test` or `python-integration-test` can prove more cheaply) — a
   conscious removal with a paper trail, never a silent `pytest.mark.skip`.

**Never permanently skip.** `@pytest.mark.skip(reason="flaky, investigate later")`
with no linked issue and no deadline is functionally identical to deleting the
test, except it still shows up in output pretending to provide coverage. The
marker plus the issue plus the deadline is the mechanism that keeps quarantine an
active queue instead of a graveyard. The quarantine list's steady state is empty;
a **growing** list is a signal about the suite's infrastructure — check the
provisioning and data-isolation standards below before assuming each new entry is
an isolated flake.

---

## Timeout and Condition-Based Waits

Every wait is a condition with a deadline (`e2e-setup-and-flow.md`'s `eventually`
helper), never `await asyncio.sleep(n)` as a completion guess. Two further guards
keep a hung system from hanging the whole suite instead of failing one test:

- **A hard per-test timeout** via `pytest-timeout` (`@pytest.mark.timeout(60)` or a
  suite-wide `timeout = 60` in `pyproject.toml`) so a genuinely stuck journey
  fails with a stack dump instead of blocking the runner until the CI job's own
  wall-clock timeout kills everything.
- **Per-call `httpx` timeouts** (the `timeout=10.0` on the `AsyncClient`) so a
  single unresponsive service surfaces as a fast, attributable failure rather than
  a client that waits indefinitely.

The `eventually` deadline, the `pytest-timeout` mark, and the `httpx` timeout are
three nested bounds: the innermost fails one assertion fast, the middle fails one
test fast, the outer is the last-resort backstop.

---

## Data Isolation and Guaranteed Teardown

Each run operates under a unique `tenant_id: e2e-<run-id>` (physical multi-tenancy
means the run's data is fully isolated from every other tenant's rows). Seeding is
**idempotent** — IDs derived deterministically from the run id, `ON CONFLICT DO
UPDATE` never a blind `INSERT` — so a seed step that retries within a run is safe:

```python
@pytest_asyncio.fixture
async def seeded_tenant(run_id: str):
    tenant = f"e2e-{run_id}"
    pool = await _admin_pool()
    await pool.execute(
        """INSERT INTO tenants (id, name) VALUES ($1, $2)
           ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name""",
        tenant, f"e2e {run_id}",
    )
    try:
        yield tenant
    finally:
        # The failure branch runs the IDENTICAL cleanup the success branch runs —
        # never happy-path-only. A finally block cannot be skipped by a raised
        # assertion mid-test, so orphaned tenant rows never accrue.
        await pool.execute("DELETE FROM tenants WHERE id = $1", tenant)
        await pool.close()
```

Cleanup is guaranteed by three independent layers, mirroring `go-e2e-test`: the
fixture's `finally` (in-runner), a workflow-level `if: always()` teardown step
(the real backstop, since a hard job timeout bypasses the fixture), and a
scheduled orphan-cluster janitor as the final net. The `finally` is the analog of
Go's `t.Cleanup` + `trap`; the `if: always()` step deletes the `kind` cluster
even when `pytest` itself is killed.

---

## Choosing the Minimal Critical-Path Set — Why E2E Stays Small

E2E is the pyramid's narrow apex. Add a journey test only when **all** of these
hold; otherwise push the coverage down a layer:

| Add an e2e journey when | Push down when |
|---|---|
| It is a P1 revenue/compliance path a broken deploy would embarrass the business (audit prep, classify, generate report) | It is a validation rule or a branch permutation → `python-unit-test` |
| It genuinely crosses a service boundary the lower layers cannot exercise together | It is one service's repository/outbox/consumer wiring → `python-integration-test` |
| Its failure mode is *integration drift* — services that pass in isolation but disagree at the wire | It is request/response shape of one handler → `python-fastapi-handler` tests |
| A human would sign off the release on seeing it green (`uat-scenario`) | It re-proves something a cheaper, faster test already proves |

The full-journey inventory should be a handful — count them on one hand per
Bounded-Context cluster, not a matrix. Each journey costs a real `kind` cluster
minute and carries a real flake budget; a suite that grows a journey per edge case
inverts the pyramid into an ice-cream cone and trains the team to distrust the
one signal that is supposed to be the highest-confidence gate. When tempted to add
an e2e for an edge case, decompose it: which unit or integration test would prove
the same thing in seconds with no network?

---

## CI Placement — Full Suite vs. Smoke Subset

The full suite runs **never on `pull_request`** — a multi-service `kind` cluster
costs minutes (not the seconds a testcontainers pair costs), and a non-zero
false-failure rate would train engineers to reflexively re-run a red required
gate. Three triggers instead:

```yaml
# .github/workflows/e2e-nightly.yml
name: e2e-journeys
on:
  schedule:
    - cron: "0 2 * * *"        # 02:00 UTC nightly — the steady-state cadence
  release:
    types: [published]          # a release must not ship on a stale nightly result
  workflow_dispatch: {}         # verify one fix without waiting for 02:00

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - id: provision
        run: ./tests/e2e/provision-kind.sh | tee -a "$GITHUB_ENV"
      - run: pytest tests/e2e -m "e2e and not quarantine" --reruns 1 -v
      - if: always()
        run: kind delete cluster --name "e2e-${GITHUB_RUN_ID}" || true
```

The tagged **`@pytest.mark.smoke`** subset runs separately and more often — on
every promotion, directly against the real dev/staging/tenant environment, as
`cd-pipeline`'s post-deploy verification and `blue-green-deployment`'s pre-cutover
gate assume:

```bash
# Post-deploy / pre-cutover smoke — a small, non-destructive slice against the real env.
E2E_BASE_URL="https://staging.example.com" \
E2E_KAFKA_BOOTSTRAP="staging-redpanda:9092" \
E2E_RUN_ID="promo-${DEPLOY_ID}" \
  pytest tests/e2e -m smoke -v
```

`e2e_test_cadence` (`sdlc-config-management`) overrides the nightly schedule for a
product that needs it tightened — the same product-specific override pattern
`go-e2e-test` and `go-mutation-test` already define. A nightly failure does not
page anyone at 2 a.m.: it opens an issue and blocks the next `dev`→`staging`
promotion (`cd-pipeline`) until the suite is green again.
