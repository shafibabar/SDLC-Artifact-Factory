# Hypothesis-Driven Experiment Design Standard

Full standard referenced from `SKILL.md`'s "Hypothesis-Driven Experiment Design" section.
Self-contained — reads without the parent body already in context. Every chaos experiment in
this repo, regardless of which fault it injects (toxiproxy latency, an app-level fault
decorator, or a `references/fault-injection-catalogue.md` infrastructure fault), is built from
the same four elements, defined **in this order, before the fault is injected**. An experiment
missing any one of the four is not a chaos experiment — it is undirected breakage.

---

## 1. Steady State — a Measurable "Healthy" Signal, Stated First

Steady state is a number pulled from the same telemetry the product runs on in production
(`opentelemetry-instrumentation`'s RED/USE metrics, queried via `prometheus-metrics-design`'s
PromQL patterns) — never an ad hoc assertion invented for the test. Two concrete examples this
repo's SLOs already ground:

```
p99(classify_data_asset_duration_seconds) < 800ms         # slo-definition's ClassifyDataAsset SLO
rate(http_server_requests_total{status=~"5.."}[1m]) < 0.001  # error rate under 0.1%
```

State the steady-state window too — a single scrape is noise; "measured over the 60s
immediately preceding fault injection" is part of the definition, not an implementation detail.
A chaos experiment that never measures steady state before injecting has no baseline to prove
recovery *against* — see `SKILL.md`'s Anti-Patterns for what this produces (an anecdote, not a
result).

---

## 2. Hypothesis — What the Resilience Pattern Under Test Should Do

One sentence, naming the specific pattern (`glossary-management`'s canonical term — **Circuit
Breaker**, **Dead Letter Queue**, **Idempotency**, never a paraphrase) and the exact behavior
expected under the fault:

> "If PostgreSQL connection-pool acquisition blocks past its configured timeout, the Circuit
> Breaker opens within 5 seconds and subsequent requests fail fast with `ErrServiceUnavailable`
> instead of queuing on the pool."

A hypothesis that only predicts failure ("the system will struggle") is unfalsifiable — it
cannot fail the experiment, so it proves nothing. A hypothesis that names a mechanism (which
pattern, which state transition, which numeric bound) can be wrong, and being provably wrong is
what makes a pass meaningful.

---

## 3. Blast-Radius Scoping — Explicit, Narrow, Escalated Only After a Clean Pass

Every experiment states, before it runs, exactly what it is allowed to touch:

| Scope | When to use | Never |
|---|---|---|
| **One canary pod** (`kubernetes-manifest`'s pod-per-replica identity, `canary-deployment`'s canary slice) | Default first run of any new experiment | Selecting by a label that matches more than one replica on a first run |
| **One tenant's traffic** (a single `tenant_id`, `multi-tenancy-design`'s physical-isolation boundary) | Verifying the fault doesn't leak across the tenant isolation the platform guarantees | Injecting a fault with no tenant scope on a multi-tenant stack — "which tenant" must always be answerable |
| **One dependency, one fault type** | Every experiment — isolate the variable | Combining two simultaneous faults (a DB latency spike *and* a broker outage) before either is independently proven |
| **The whole fleet / all tenants** | Only after every narrower scope has passed cleanly, and only with the Safety Rails in `references/safety-rails-standard.md` active | A first run against unscoped production traffic — see `SKILL.md`'s Safety Rails section |

Tenant isolation is itself a testable hypothesis under this scoping rule: injecting a fault
against tenant A's stack and asserting tenant B's steady state never moves is how the physical
multi-tenancy guarantee (`multi-tenancy-design`) gets chaos-tested, not just design-reviewed.

---

## 4. Rollback Trigger — an Exact, Automatic Condition, Set Before Starting

The rollback trigger is a number, decided and written down **before the fault is injected**,
never a judgment call made while watching a dashboard mid-experiment:

```
ABORT IF: error_rate > 5%  OR  steady_state_slo_breach > 60s continuous
```

The trigger is wired to fire automatically — the same automated-abort mechanism
`references/safety-rails-standard.md` specifies, not a human who might be away from the
dashboard at the moment it matters. A rollback trigger decided *after* the experiment starts
degrading is not a safety rail; it is a post-hoc rationalization of however bad things were
allowed to get.

---

## The Four Elements as a Test Header

Every chaos experiment states all four as a comment block immediately above the test function —
reviewable by Shafi without running the code:

```go
// EXPERIMENT: Circuit Breaker opens on Postgres pool exhaustion
// STEADY STATE:  p99 classify latency < 800ms, error rate < 0.1%  (60s pre-fault window)
// HYPOTHESIS:    pool acquisition blocking >2s trips the breaker; requests fail fast, not hang
// BLAST RADIUS:  one canary pod, tenant=chaos-test-tenant, Postgres pool only
// ROLLBACK:      abort if error_rate > 5%  OR  steady-state breach sustained > 60s
func TestCircuitBreaker_OpensOnPoolExhaustion(t *testing.T) { /* ... */ }
```

This block is the artifact a PM reviews to judge whether an experiment is well-formed — before
reading a line of Go. An experiment whose header is missing any of the four lines fails review
regardless of what the test body does.
