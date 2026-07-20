---
name: canary-deployment
description: >
  Teaches Canary Deployment as the default progressive delivery strategy —
  staged traffic shifting on the Linkerd Service Mesh with weighted routing
  (5/25/50/100 with hold times), SLO burn-rate and error/latency gates per
  stage that auto-rollback on breach, per-tenant canary waves under physical
  multi-tenancy, and the boundary of what cannot canary (partitioned event
  consumers, schema changes) with fallback strategies. Used by the
  platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, canary, progressive-delivery, linkerd, traffic-split, burn-rate, rollback]
---

# Canary Deployment

## Purpose

**Canary Deployment** is the default progressive delivery strategy on this platform: a new version receives a small, increasing share of live traffic while automated gates watch it against the same Service Level Objectives (`slo-definition`) the stable version is held to. If the new version burns error budget faster than the gate allows, the rollout stops and reverts automatically — no human has to notice a dashboard trending red at 2 a.m.

Where `blue-green-deployment` is a binary switch reserved for schema cutovers and instant-rollback needs, canary is gradual and reserved for the common case: an ordinary service release that traffic can be shifted onto in stages, each stage cheaper to abandon than the last. The agent's directive is explicit: canary, gated on SLO burn, is the default; big-bang deploys are forbidden in production.

---

## Staged Traffic Shifting with Linkerd

The mesh (Linkerd, already present for mTLS per `kubernetes-manifest`) does the traffic split — no separate ingress-layer canary controller needed, which keeps the frugal footprint down. Weighted routing via Linkerd's `HTTPRoute`/`TrafficSplit` resources shifts a percentage of requests to the canary backend:

```yaml
# templates/canary-httproute.yaml
apiVersion: policy.linkerd.io/v1beta3
kind: HTTPRoute
metadata:
  name: estate-scanner
spec:
  parentRefs:
    - name: estate-scanner
      kind: Service
  rules:
    - backendRefs:
        - name: estate-scanner-stable
          port: 8080
          weight: 95          # stage 1: 5% canary
        - name: estate-scanner-canary
          port: 8080
          weight: 5
```

The standard stage progression, each stage a values change (or an automated step-function if a rollout controller is in play — see below), with a **hold time** before advancing so the burn-rate windows below have enough signal:

| Stage | Canary weight | Minimum hold | Advances if |
|---|---|---|---|
| 1 | 5% | 15 min | Fast-burn gate clean for the full hold |
| 2 | 25% | 30 min | Fast-burn + slow-burn gates clean |
| 3 | 50% | 30 min | Fast-burn + slow-burn gates clean |
| 4 | 100% | — | Terminal — canary Deployment becomes the new stable, old stable scales down |

Any gate breach at any stage **halts and reverts to 0% canary weight** immediately — the stage table is a ratchet forward only when clean, never a schedule that proceeds regardless.

### Automation note

The stage progression above can run as manual, reviewed PRs to the weight values (consistent with every other GitOps change) for a Han-Solo-scale operator, or be automated with a lightweight rollout controller (e.g. Flagger, which drives Linkerd `HTTPRoute` weights directly from Prometheus queries) once the manual cadence becomes the bottleneck. Manual-via-PR is the frugal default; Flagger is the documented upgrade path, recorded as an ADR when adopted — it adds an operator to the cluster, which is exactly the kind of tooling decision that needs justification against the frugality constraint.

---

## Gate Metrics per Stage

Every stage gates on the same signals `alerting-rules-design` already pages on — canary does not invent a parallel metrics system, it reads the recorded burn-rate series and applies them to the canary's traffic slice specifically:

| Gate | Source | Threshold | Applies at |
|---|---|---|---|
| **SLO fast-burn** | `service:http_request_errors:ratio_rate5m{slot="canary"}` recording series (`prometheus-metrics-design`) | > 14.4 × budget fraction, sustained 5m | Every stage |
| **Error rate vs baseline** | Canary error ratio vs stable's error ratio, same window | Canary must not exceed stable by more than 1.5x | Every stage |
| **p99 latency vs baseline** | Canary p99 vs stable p99, same window | Canary must not exceed stable's p99 by more than 20% | Every stage |
| **Freshness (pipeline services)** | End-to-end freshness SLI computed for canary-tagged messages only | Must stay within the SLO target | Stage advance only, not continuous (freshness has a longer natural lag) |

```yaml
# rules/canary-gate-estate-scanner.yaml
groups:
  - name: canary-gate-estate-scanner
    rules:
      - alert: CanaryFastBurnBreach
        expr: |
          service:http_request_errors:ratio_rate5m{service="estate-scanner", slot="canary"}
            > (14.4 * 0.005)
        for: 5m
        labels: { severity: page, action: auto-rollback }
        annotations:
          summary: "estate-scanner canary burning error budget at 14.4x — auto-reverting to 0%"
          runbook_url: "runbooks/estate-scanner/canary-rollback.md"
      - alert: CanaryLatencyRegression
        expr: |
          (
            histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="estate-scanner", slot="canary"}[10m])))
            /
            histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="estate-scanner", slot="stable"}[10m])))
          ) > 1.2
        for: 10m
        labels: { severity: page, action: auto-rollback }
        annotations:
          summary: "estate-scanner canary p99 is 20%+ worse than stable"
          runbook_url: "runbooks/estate-scanner/canary-rollback.md"
```

**Automatic rollback on breach**: the `action: auto-rollback` label is what a rollout controller (or the on-call, if running the manual cadence) acts on — weight reverts to 0% canary, the alert's `runbook_url` documents the exact revert steps per `runbook-authoring`. This is the same alerting infrastructure the platform already runs; canary gates are not a second alerting system, they are `alerting-rules-design`'s rules scoped by the `slot` label.

---

## Per-Tenant Canary Under Physical Multi-Tenancy

Two canary layers exist simultaneously, and they are not the same thing:

1. **In-cluster traffic canary** (above) — within *one* tenant's namespace, shifting weight between stable and canary Pods of the same service.
2. **Tenant-wave canary** (`cd-pipeline`'s fleet promotion model) — the designated canary tenant receives the new digest *before* the rest of the fleet, and only after that tenant's in-cluster canary rollout completes cleanly does the wave PR promote the remaining tenants.

The two compose: a release ships in-cluster canary (5→25→50→100) inside `tenant-canary`'s namespace first; only once it reaches 100% and bakes does the fleet-wave PR carry the *same, already-proven* digest to `tenant-acme`, `tenant-globex`, and the rest — where it goes through its own in-cluster canary again, because per-tenant load profiles and data shapes differ enough that a clean canary tenant does not guarantee a clean fleet tenant. Skipping the second in-cluster canary "because the canary tenant already proved it" reintroduces the big-bang risk physical isolation was bought to prevent.

---

## What Cannot Canary

Not every workload has a "percentage of traffic" concept. Two structural exceptions:

| Workload | Why it can't canary normally | Strategy |
|---|---|---|
| **Consumers on partitioned Redpanda topics** | Consumer group membership is all-or-nothing per partition — there is no "5% of messages" the way there's 5% of HTTP requests; a partition is owned by exactly one consumer instance at a time | **Canary by partition share**: assign the canary instance a subset of partitions (via a static partition assignment or a `consumer.max.poll.records`-scoped subset) so it processes a *bounded, known slice* of real traffic while the rest of the partitions stay on stable instances. If partition-level canary isn't practical for the topic's key distribution, **fall back to `blue-green-deployment`** — pause-then-cutover is well-defined for consumers in a way that partial traffic is not. |
| **Schema changes** | A canary that writes under a new schema shape while stable writes under the old one is two schemas in flight — the same problem `blue-green-deployment`'s database rule forbids | Schema changes ride the **expand/contract** discipline (`go-migration`) regardless of which deployment strategy is chosen; the canary's *code* rollout can still be gradual, but the schema itself is expanded ahead of time, straddled by both stable and canary, and contracted only after the release is fully rolled out and baked — exactly as in blue-green. |

The rule in one line: **canary needs a dial; if the workload only has a switch, use `blue-green-deployment` instead** — the two skills are complements, not alternatives to argue between per release.

---

## Worked Example — Staged Rollout for estate-scanner

Rolling out a change to `estate-scanner`'s document-fingerprinting logic (affects the `DocumentDiscovered` event payload's `content_hash` field — additive, so no schema exception applies):

```yaml
# deploy/clusters/tenants/tenant-canary/estate-scanner-canary-route.yaml
apiVersion: policy.linkerd.io/v1beta3
kind: HTTPRoute
metadata: { name: estate-scanner }
spec:
  parentRefs: [{ name: estate-scanner, kind: Service }]
  rules:
    - backendRefs:
        - { name: estate-scanner-stable, port: 8080, weight: 95 }
        - { name: estate-scanner-canary, port: 8080, weight: 5 }
```

Gate rules scoped to this release, referencing the recorded series from `prometheus-metrics-design` and the SLO from `slo-definition`:

```yaml
groups:
  - name: canary-gate-estate-scanner-fingerprint-release
    rules:
      - alert: CanaryFastBurnBreach
        expr: service:http_request_errors:ratio_rate5m{service="estate-scanner", slot="canary"} > 0.072
        for: 5m
        labels: { severity: page, action: auto-rollback, stage: "5,25,50" }
        annotations: { runbook_url: "runbooks/estate-scanner/canary-rollback.md" }
      - alert: CanaryContentHashMismatch
        expr: increase(estate_scanner_content_hash_mismatch_total{slot="canary"}[15m]) > 0
        for: 5m
        labels: { severity: page, action: auto-rollback, stage: "5,25,50" }
        annotations:
          summary: "Canary is producing content_hash values that disagree with stable on the same document set"
          runbook_url: "runbooks/estate-scanner/canary-rollback.md"
```

Sequence: stage 1 (5%, 15 min hold) clean → stage 2 (25%, 30 min) clean → stage 3 (50%, 30 min) clean → stage 4 (100%, terminal) → `estate-scanner-canary` Deployment is relabeled `stable`, the old stable Deployment scales down. The `tenant-canary` wave completing cleanly is the gate for the `cd-pipeline` fleet-wave PR to `tenant-acme` and `tenant-globex`, where the same four-stage sequence runs again against each tenant's own traffic.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Default strategy | Canary used for ordinary, request-driven releases | Big-bang deploys in production |
| Staged weights | 5→25→50→100 with hold times, ratchet-forward only | Weight jumps straight to 100%, or no hold time to gather signal |
| Gates read SLOs | Burn-rate, error-rate, latency gates use the same recorded series as `alerting-rules-design` | Ad-hoc thresholds invented per rollout |
| Auto-rollback | Breach reverts weight to 0% without waiting for a human | Breach only pages; rollout continues by default |
| Runbook linked | Every gate alert carries a `runbook_url` per `alerting-rules-design`'s hygiene rule | Gate alerts with no documented revert procedure |
| Per-tenant waves | Canary tenant proves in-cluster canary before fleet wave promotes | Fleet-wide promotion skipping per-tenant canary |
| Boundary respected | Partitioned consumers canary by partition share or fall back to blue-green; schema changes ride expand/contract | Partial-traffic canary attempted on a workload with no traffic dial |
| Mesh-native | Linkerd `HTTPRoute`/`TrafficSplit` weights, no added ingress-layer canary controller unless justified by ADR | A second canary system duplicating what the mesh already provides |

---

## Anti-Patterns

- **Canarying a consumer group like an HTTP service** — attempting a "5% traffic" canary on a Redpanda consumer without a partition-level assignment either double-processes messages or silently canaries 0% of real traffic depending on which instance the rebalance favors. Use partition-share canary or blue-green.
- **No hold time** — advancing stages the instant the previous stage's weight applies gives the burn-rate windows no chance to accumulate signal; a 5-minute-old canary at 5% traffic has not generated enough requests to trust a burn-rate number yet.
- **Gates that only page** — an alert firing while the rollout controller (or the on-call, unprompted) keeps advancing weight anyway is theatre. The breach must halt and revert automatically, or a human must be the automation with an SLA tighter than the next stage's schedule.
- **Skipping the fleet tenant's own canary** — trusting the canary tenant's clean result to greenlight every other tenant at 100% ignores that tenant workloads differ; the fleet wave promotes the *digest*, not an exemption from re-canarying.
- **Canary weight left non-zero indefinitely** — a rollout stuck at 25% for weeks because nobody closed it out is neither rolled back nor rolled forward; it is undecided state that complicates the next release. Every canary terminates at 0% or 100%.
- **A second alerting stack for canaries** — building bespoke canary dashboards and thresholds disconnected from `alerting-rules-design`'s SLO burn-rate rules duplicates work and can disagree with the numbers the rest of the platform trusts.
- **Schema drift under partial traffic** — writing under a new schema shape at 5% canary while 95% of traffic writes the old shape is exactly the dual-schema problem `blue-green-deployment` forbids, just spread across a longer window. Expand first, always.

---

## Output Format

Produces the canary rollout plan and gate configuration for a release:

```markdown
---
name: canary-deployment-[service]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Canary Deployment — [service]

## Strategy Confirmation
[Why canary fits this release — traffic-driven, no schema exception, no partition constraint]

## Traffic Route
charts/[service]/templates/canary-httproute.yaml

## Stage Plan
| Stage | Weight | Hold time | Advance condition |

## Gate Rules
prometheus/rules/canary-gate-[service]-[release].yaml
[Fast-burn, error-vs-baseline, latency-vs-baseline, freshness thresholds]

## Per-Tenant Wave
[Canary tenant result; fleet wave PR reference]

## Rollback Evidence
[Last auto-rollback drill: trigger, time-to-revert]

## Traceability
[SLO IDs (slo-definition); NFR IDs behind rollout risk tolerance]
```
