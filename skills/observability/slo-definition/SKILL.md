---
name: slo-definition
description: >
  Teaches how to define Service Level Objectives — selecting the right Service
  Level Indicators per service type (availability, latency, freshness,
  correctness), setting targets from user journeys rather than nines-vanity,
  error budget arithmetic, burn rate as the spend-speed measure, the
  multiwindow policy that alerting builds on, and the review cadence that keeps
  targets honest. Turns the NFR specification into measurable, enforceable
  operational targets. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, observability, slo, sli, error-budget, burn-rate, reliability]
---

# SLO Definition

## Purpose

A Service Level Objective (SLO) is the bridge between what users need and what operations enforces. Without one, "is the service reliable enough?" has no answer — every incident is an argument and every alert threshold is a guess. With one, reliability becomes a budget: measurable, spendable, and defensible to a customer.

Three terms, used exactly (canonical glossary):

- **Service Level Indicator (SLI)** — a quantitative measure of the level of service being provided (e.g. request success rate, latency at the 99th percentile).
- **Service Level Objective (SLO)** — a target value or range for an SLI. SLOs are the internal target.
- **Service Level Agreement (SLA)** — the formal external contract with a customer, with penalties for breach. The SLA is always *looser* than the SLO, so the internal target trips first and there is room to react before money is owed.

The chain through the factory: `nfr-specification` (Discovery) states the reliability requirements → this skill formalises them as SLIs and SLOs → `prometheus-metrics-design` computes the SLIs as recorded series → `alerting-rules-design` pages on budget burn → `go-load-test` verifies the targets hold under peak load before release.

---

## SLI Selection per Service Type

An SLI is always a ratio: **good events / valid events**, over a window. Choose the dimension that matches what the service's users actually experience:

| SLI type | Measures | Good event | Fits |
|---|---|---|---|
| **Availability** | Did it answer? | response that is not a 5xx | every synchronous API |
| **Latency** | Did it answer in time? | request completing under the threshold | every synchronous API |
| **Freshness** | Is the async result recent enough? | item processed end-to-end within the deadline | pipelines, Read Model projections |
| **Correctness** | Was the answer right? | unit of work processed without landing in the Dead Letter Queue (DLQ) or failing validation | event consumers, pipelines |

For the data-estate product, the DataAsset classification pipeline is asynchronous Event Choreography — estate-scanner discovers a DataAsset, entity-extractor extracts entities, compliance-engine classifies. An availability SLO on each service would all be green while classifications sit hours behind; the user-facing truth is **freshness**. Each service also keeps RED-based availability and latency SLIs on its own interfaces (`opentelemetry-instrumentation` emits them):

| Service / journey | SLI | Definition (good / valid) |
|---|---|---|
| ClassifyDataAsset command API (compliance-engine) | Availability | non-5xx responses / all requests to `PATCH /v1/data-assets/{id}/classification` |
| ClassifyDataAsset command API | Latency | requests completing < 800ms / all requests (bucket boundary at 0.8s — `prometheus-metrics-design`) |
| Classification pipeline end-to-end | **Freshness** | DataAssets classified within 15 minutes of discovery / all DataAssets discovered |
| entity-extractor consumer | Correctness | documents processed with `outcome="ok"` / all documents consumed (DLQ and error outcomes are bad events) |

The freshness SLI is measured from the Domain Event timestamps the pipeline already publishes (`DataAssetDiscovered` → `DataAssetClassified`), recorded into the end-to-end histogram whose buckets bracket the 15-minute deadline.

---

## Setting Targets — Journeys, Not Nines-Vanity

The method, in order:

1. **Start from the user journey.** What does a compliance officer actually tolerate? A dashboard whose classifications are 15 minutes stale is fine; 4 hours stale undermines an audit. The `nfr-specification` captures this — the SLO formalises it.
2. **Measure current performance first.** Run the service under realistic load (`go-load-test`) and take the achieved baseline. An SLO set above what the architecture can deliver is a standing false alarm.
3. **Set the target just tight enough to protect the journey.** Each extra nine roughly multiplies cost and constrains change: 99.5% allows ~3.4 h/month of bad minutes; 99.99% allows ~4 minutes — the latter demands multi-zone redundancy the frugal posture and a B2B SaaS audience do not justify at MVP.
4. **Derive the SLA from the SLO, looser.** Internal 99.5% might back an external 99.0% commitment.
5. **Treat the remaining budget as fuel for change.** Budget left over is spent on deploys, migrations, and Canary Deployment experiments — not banked.

Sensible MVP targets for the product: **99.5%** availability and latency on the command API, **99%** pipeline freshness within 15 minutes, **99.9%** consumer correctness — all over rolling 28 days.

---

## Error Budget Math — Worked Example

The error budget is `1 − SLO target`: the amount of bad service that is *allowed*. For the ClassifyDataAsset API at **99.5% over a rolling 28 days**:

```
Budget fraction        = 1 − 0.995            = 0.5%
Window                 = 28 d × 24 h × 60 min = 40,320 minutes
Time-based budget      = 0.5% × 40,320        ≈ 201.6 minutes  (~3 h 22 m of bad minutes)
Request-based budget   = at 20 M requests / 28 d:
                         0.5% × 20,000,000    = 100,000 failed or slow requests
```

Every 5xx and every response slower than 800ms spends the budget. A 30-minute incident with 100% errors at 500 rpm spends 15,000 requests — 15% of the budget in one afternoon. When the budget is exhausted, feature deploys pause and reliability work takes priority; that policy is written into the SLO document so the trade-off is decided in advance, not mid-incident.

---

## Burn Rate — How Fast the Budget Is Being Spent

Burn rate normalises the current error ratio against the budget:

```
burn rate = observed error ratio / budget fraction
```

- Burn rate **1** — spending exactly on pace; the budget lasts the full 28 days.
- Burn rate **6** — the budget is gone in 28 d ÷ 6 ≈ 4.7 days.
- Burn rate **14.4** — the budget is gone in ~2 days; a serious incident is in progress.

Burn rate is what makes SLOs *enforceable*: a fixed error-rate threshold either pages too early or too late, while burn rate asks the only question that matters — at this pace, does the budget survive the window?

**Multiwindow policy.** A burn rate measured over one short window is noisy (a single bad minute spikes it); over one long window it is sluggish (the alert keeps firing after recovery). The policy therefore evaluates each condition over a *long* window (is this real?) **and** a *short* window (is it still happening?) simultaneously — e.g. 1 h + 5 m for fast burn, 6 h + 30 m for slow burn. The concrete thresholds, standard table, and PromQL are `alerting-rules-design`'s job; the SLO document declares which windows and burn rates apply to each SLO.

---

## Review Cadence

SLOs are living targets, reviewed on a schedule — not set once:

| Cadence | Review |
|---|---|
| Monthly | Budget consumption per SLO; incidents that spent it; alert noise from `alerting-rules-design` |
| Quarterly | Are targets still right? Consistently 100% → consider tightening, or bank the slack as deploy freedom. Chronically breached → fix the service or loosen the target honestly |
| On change | New user journey, new NFR, new tenant tier, or architecture change (e.g. Circuit Breaker or Transactional Outbox altering failure modes) → revisit affected SLIs |

An SLO nobody reviews decays into either a false comfort (always green, protecting nothing) or wallpaper (always red, ignored). Both are recorded failures at review, with an action.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| SLI form | Good/valid ratio with a precise, measurable definition | Vague "service should be fast" statements |
| SLI fit | Freshness/correctness for async work; availability/latency for sync | Availability-only SLOs on an async pipeline |
| Target grounding | Derived from user journey and measured baseline | Nines chosen for marketing symmetry |
| Budget arithmetic | Budget computed in time and requests; spend policy written | Target with no stated consequence when exhausted |
| SLO vs SLA | SLA looser than SLO; both documented | Terms used interchangeably; SLA equals SLO |
| Measurability | Each SLI is a recorded Prometheus series (`prometheus-metrics-design`) | SLI that no existing metric can compute |
| Enforcement chain | Burn-rate windows declared; wired to `alerting-rules-design`; verified by `go-load-test` | SLO document disconnected from alerts and tests |
| Review | Cadence with owner and dates | Set-and-forget targets |

---

## Anti-Patterns

- **Nines-vanity** — "five nines" on an MVP B2B SaaS whose users tolerate minutes of staleness buys pager fatigue and multi-zone cost for zero user-perceived value. Targets come from journeys.
- **Availability SLOs on an async pipeline** — every service up, every classification six hours late, every SLO green. Freshness is the user's truth for Event Choreography.
- **SLO equals SLA** — the internal target and the external promise trip simultaneously, so the first warning of breach is a penalty clause. The SLO always trips first.
- **100% as a target** — a zero-size error budget means any single failed request is a breach and no deploy is ever safe. Perfection is not an engineering target.
- **Unmeasurable SLIs** — "99% of classifications are accurate" without a defined good/valid event and a series to compute it is a wish, not an SLI.
- **Averages as SLIs** — mean latency under 300ms can hide a p99 of 8 seconds. SLIs use threshold ratios or percentiles, never means.
- **Budget as a scoreboard only** — tracking burn without the pre-agreed spend policy (budget out → deploys pause) makes the SLO advisory, and advisory targets lose every scheduling argument.

---

## Output Format

Produces the SLO document — one per product, covering every service:

```markdown
---
name: slo-definition-<product>
product: <product-name>
version: 1.0.0
phase: deploy
created: <date>
owner: platform-engineer
---

# Service Level Objectives — <Product>

## Sources
[NFR specification reference; user journeys each SLO protects]

## SLOs
| # | Service / journey | SLI (good / valid events) | Measurement (recorded series) | Target | Window |

## Error Budgets
| SLO | Budget (time) | Budget (requests/items) | Spend policy when exhausted |

## Burn-Rate Policy
| SLO | Fast-burn windows / threshold | Slow-burn windows / threshold | → alerting-rules reference |

## SLA Mapping
| External SLA commitment | Backing SLO | Headroom |

## Review
| Cadence | Owner | Last reviewed | Actions |
```
