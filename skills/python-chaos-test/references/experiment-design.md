# Chaos Experiment Design — Hypothesis, Blast Radius, Corrective Action

Full standard referenced from `SKILL.md`'s "Hypothesis-Driven Experiment Shape",
"Safety Rails", and "Corrective-Action Output" sections. Self-contained — reads
without the parent body already in context. Every chaos experiment in this repo,
whatever fault it injects (a toxiproxy wire fault or a testcontainers dependency
kill from `references/toxiproxy-fault-injection.md`), is built from the same four
elements, defined **in this order, before the fault is injected**. An experiment
missing any one of the four is not a chaos experiment — it is undirected
breakage.

---

## The Hypothesis Template

Copy this block verbatim above every experiment's test function and fill each
line. It is the artifact Shafi reviews to judge whether an experiment is
well-formed — before reading a line of Python.

```python
# EXPERIMENT:   <one line: which pattern this proves, under which fault>
# STEADY STATE: <a number from real telemetry + the window it is measured over>
# HYPOTHESIS:   <one falsifiable sentence: the exact pattern + the state
#               transition expected under the fault + a numeric bound>
# BLAST RADIUS: <one tenant / one dependency / one fault type; ephemeral stack>
# ROLLBACK:     <an exact automatic abort condition, decided now, not mid-run>
```

### 1. Steady state — a measurable "healthy" signal, stated first

A number pulled from the same telemetry the product runs on
(`opentelemetry-instrumentation`'s RED/USE metrics), never an assertion invented
for the test. State the **window** too — a single sample is noise:

```
p99(classify_duration_seconds) < 0.8          # over the 60s pre-fault window
rate(requests_total{status=~"5.."}[1m]) < 0.001   # error rate under 0.1%
```

Without a steady-state baseline measured *before* injection there is nothing to
prove recovery *against*, and the experiment produces an anecdote, not a result.

### 2. Hypothesis — falsifiable, names the pattern

One sentence naming the canonical pattern (`glossary-management`'s **Circuit
Breaker** / **Dead Letter Queue** / **Idempotency**, never a paraphrase) and the
exact behaviour:

> "If the Postgres link is severed, the Circuit Breaker opens within 5s and
> subsequent calls fail fast with `ServiceUnavailableError` instead of hanging on
> the dead socket; once the link heals, the breaker's half-open probe closes it
> and steady state returns within 30s."

A hypothesis that only predicts failure ("the system will struggle") cannot fail
the experiment, so it proves nothing. A hypothesis that names a mechanism — which
pattern, which state transition, which numeric bound — can be wrong, and being
provably wrong is what makes a pass meaningful.

### 3. Blast-radius scoping

| Scope | When | Never |
|---|---|---|
| **One ephemeral testcontainers stack** | Default first run of any new experiment | A shared or long-lived environment on a first run |
| **One tenant** (a single `tenant_id`, `multi-tenancy-design`'s physical-isolation boundary) | Verifying the fault does not leak across the tenant boundary the platform guarantees | Injecting a fault with no tenant scope on a multi-tenant stack |
| **One dependency, one fault type** | Every experiment — isolate the variable | Two simultaneous faults (DB latency *and* a broker kill) before either is proven alone |
| **A wider slice** | Only after every narrower scope passes cleanly, and only in a non-production environment | A first run against a shared/production environment |

Tenant isolation is itself a testable hypothesis: inject a fault against tenant
A's stack, assert tenant B's steady state never moves — that is how the physical
multi-tenancy guarantee gets chaos-tested rather than only design-reviewed.

### 4. Rollback trigger — exact, automatic, decided first

A number written down before injection, never a judgment call made while watching
output scroll by:

```
ABORT IF error_rate > 5%  OR  steady_state_breach sustained > 60s continuous
```

---

## Async Automatic-Abort Task

Because the whole experiment runs in one async process, the abort *is* Python —
no external alerting system is needed the way Chaos Mesh experiments in
`go-chaos-test` need a `PrometheusRule` + watcher. An `asyncio` task polls the
steady-state signal and removes the fault the instant the numeric trigger is
crossed:

```python
import asyncio, time

async def run_with_abort(*, inject, remove, breached, budget_s: float):
    """Inject a fault, watch the abort condition, guarantee removal.

    inject/remove: callables that add/remove the fault (toxic or container kill).
    breached: async predicate — True the moment the rollback trigger is crossed.
    budget_s: hard ceiling; the experiment never runs longer than this.
    """
    inject()
    watchdog = asyncio.create_task(_watch(breached, budget_s))
    try:
        await watchdog
    finally:
        remove()            # fault removed on abort, timeout, AND normal completion

async def _watch(breached, budget_s: float):
    deadline = time.monotonic() + budget_s
    while time.monotonic() < deadline:
        if await breached():
            return          # trip → return → finally removes the fault
        await asyncio.sleep(0.25)   # poll cadence ONLY; never a "wait for recovery" sleep
```

The `asyncio.sleep(0.25)` here is a **poll cadence**, not a "give it a second"
guess — the distinction the anti-patterns draw. Recovery itself is always waited
for with a deadline-bounded `poll_until`, never a fixed sleep:

```python
async def poll_until(predicate, *, timeout: float, interval: float = 0.1) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if await _maybe_await(predicate()):
            return True
        await asyncio.sleep(interval)
    return False
```

---

## Safety Rails — Environment Restriction

No chaos experiment's **first run** targets a shared or production environment.
The stages a new experiment graduates through:

| Stage | Environment | Affects |
|---|---|---|
| 1 — First run, always | An ephemeral testcontainers stack (Postgres + Redpanda + toxiproxy), spun and torn down per test | Nothing real; a synthetic `chaos-tenant` only |
| 2 — Confidence-building | A dedicated non-production namespace, still tenant-scoped | One synthetic tenant's slice |
| 3 — Only after 1 and 2 pass cleanly, repeatedly | A wider non-production slice, still tenant-scoped | One tenant, never the full fleet |
| Never, on a first run | A shared or production environment | — |

`@pytest.mark.chaos` gates the whole suite so `pytest -m "not chaos"` skips it
where Docker is unavailable (the analog of a load or integration marker). An
experiment that has never passed at Stage 1 has no evidence-based reason to run
at Stage 2.

---

## Corrective-Action Output — Ties to `disaster-recovery-plan`

A failed experiment is a **finding**: it names a resilience assumption that does
not hold. Every failing experiment yields a corrective action, and that action is
the bridge to `disaster-recovery-plan` — the experiment proves *whether* the
system recovers; the recovery plan documents *how an operator makes it recover*
when the automatic path is insufficient.

| Experiment failure | What it reveals | Corrective action → `disaster-recovery-plan` |
|---|---|---|
| Breaker never opens on a severed link (calls hang) | Missing/misconfigured Circuit Breaker or no socket timeout | Set the breaker threshold + a connect/read timeout; add the "downstream hung" manual-failover procedure to the DR runbook |
| Breaker opens but never re-closes after recovery | Half-open probe missing or its interval too long | Fix the half-open config; DR runbook records the manual breaker-reset step as a fallback |
| Outbox row lost during a broker outage | Relay is not durable across the outage (data loss) | Fix the outbox persistence/relay; DR runbook gains a "replay unpublished outbox rows" recovery procedure with the RPO it implies |
| Consumer does not resume from its committed offset | Offset commit or restart handling is wrong | Fix commit-after-process; DR runbook documents the offset-reset recovery step and its at-least-once consequences |
| Idempotency breaks under redelivery (double-apply) | Dedup key/store is wrong | Fix the dedup key; DR runbook notes the reconciliation procedure for any duplicates that already landed |

The durable record of an experiment is the test code plus the telemetry it ran
against; `docs/quality/resilience-report.md` is the reviewable summary — which
patterns were validated, at which blast-radius stage, and which findings fed a
new or updated `disaster-recovery-plan` procedure.

---

## What Makes an Experiment Well-Formed — Review Checklist

- All four header lines present and filled, each decided **before** injection.
- Steady state is a real telemetry number with a stated window, not an invented
  assertion.
- The hypothesis names a canonical pattern and a falsifiable numeric transition.
- Blast radius is one tenant / one dependency / one fault, in an ephemeral stack.
- The rollback trigger is a number wired to an automatic async abort task.
- The experiment asserts **both** containment (fail-fast) and recovery (poll to
  steady state), never only the failure.
- Any failure maps to a concrete corrective action and, where relevant, a
  `disaster-recovery-plan` procedure.
