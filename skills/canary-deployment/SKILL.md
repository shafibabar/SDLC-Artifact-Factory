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
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, canary, progressive-delivery, linkerd, traffic-split, burn-rate, rollback, argo-rollouts]
related: [progressive-delivery, kubernetes-workload-patterns, alerting-rules-design, slo-definition]
---

# Canary Deployment

## Purpose

**Canary Deployment** is the default progressive delivery strategy on this platform: a new version receives a small, increasing share of live traffic while automated gates watch it against the same Service Level Objectives (`slo-definition`) the stable version is held to. If the new version burns error budget faster than the gate allows, the rollout stops and reverts automatically — no human has to notice a dashboard trending red at 2 a.m.

Where `blue-green-deployment` is a binary switch reserved for schema cutovers and instant-rollback needs, canary is gradual and reserved for the common case: an ordinary service release that traffic can be shifted onto in stages, each stage cheaper to abandon than the last. The agent's directive is explicit: canary, gated on SLO burn, is the default; big-bang deploys are forbidden in production.

**Decision framework**: `progressive-delivery` owns the when-canary-vs-blue-green and when-to-add-feature-flags decision framework. This skill focuses on **how** to execute a canary rollout once the strategy is chosen.

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

The standard stage progression, each stage a values change (or an automated step-function when Argo Rollouts is in play — see below), with a **hold time** before advancing so the burn-rate windows have enough signal:

| Stage | Canary weight | Minimum hold | Advances if |
|---|---|---|---|
| 1 | 5% | 15 min | Fast-burn gate clean for the full hold |
| 2 | 25% | 30 min | Fast-burn + slow-burn gates clean |
| 3 | 50% | 30 min | Fast-burn + slow-burn gates clean |
| 4 | 100% | — | Terminal — canary Deployment becomes the new stable, old stable scales down |

Any gate breach at any stage **halts and reverts to 0% canary weight** immediately — the stage table is a ratchet forward only when clean, never a schedule that proceeds regardless.

### Automation note

The stage progression runs as manual, reviewed PRs (the frugal default for a Han Solo operator) or automated via **Argo Rollouts** — the GitOps-native upgrade path that drives Linkerd `HTTPRoute` weights from `AnalysisTemplate` results directly. Both are consistent with the GitOps change-as-PR discipline; Argo Rollouts adds an operator to the cluster — justify against frugality, record in an ADR when adopted.

---

## Gate Metrics per Stage

Every stage gates on the same signals `alerting-rules-design` already pages on — canary does not invent a parallel metrics system, it reads the recorded burn-rate series and applies them to the canary's traffic slice specifically:

| Gate | Source | Threshold | Applies at |
|---|---|---|---|
| **SLO fast-burn** | `service:http_request_errors:ratio_rate5m{slot="canary"}` recording series (`prometheus-metrics-design`) | > 14.4 × budget fraction, sustained 5m | Every stage |
| **Error rate vs baseline** | Canary error ratio vs stable's error ratio, same window | Canary must not exceed stable by more than 1.5x | Every stage |
| **p99 latency vs baseline** | Canary p99 vs stable p99, same window | Canary must not exceed stable's p99 by more than 20% | Every stage |
| **Freshness (pipeline services)** | End-to-end freshness SLI computed for canary-tagged messages only | Must stay within the SLO target | Stage advance only, not continuous (freshness has a longer natural lag) |

**Automatic rollback on breach**: gate alert labels carry `action: auto-rollback` — the rollout controller (or the on-call running the manual cadence) reverts weight to 0% immediately. Every gate alert carries a `runbook_url` per `runbook-authoring`'s hygiene rule. Full gate rule YAML, AnalysisTemplate definitions, and the worked estate-scanner example: `references/argo-rollouts-canary.md`.

---

## Argo Rollouts: GitOps-Native Canary Implementation

**Argo Rollouts** is the recommended automation path when manual-via-PR becomes the bottleneck. Its `Rollout` CRD replaces the plain `Deployment` for any service using progressive delivery — see `kubernetes-workload-patterns` for the workload-type decision (stateless service without progressive delivery → `Deployment`; progressive delivery service → `Rollout`).

A `Rollout` embeds the canary strategy — steps, weights, pauses — and attaches `AnalysisTemplate` CRDs via the `analyses` field on each step. At every step, Argo Rollouts creates an `AnalysisRun` that evaluates the Prometheus burn-rate query defined in the `AnalysisTemplate`. If the `AnalysisRun` fails (query result exceeds threshold for the configured duration), the `Rollout` auto-reverts to 0% canary weight without waiting for a human. This is the concrete GitOps-native implementation of the "SLO burn-rate gate that auto-rollbacks on breach" described in the gate table above.

**Why `AnalysisTemplate` over a CI gate script**: gate criteria in an `AnalysisTemplate` live in Git — peer-reviewed, auditable, and GitOps-reconciled by Argo Rollouts, not a CI script that can be bypassed or modified mid-flight. A failed `AnalysisRun` is a versioned Kubernetes resource visible in `kubectl get analysisrun` and the Argo Rollouts UI; a failed CI step is a log artifact. This closes the GitOps coherence gap: the entire delivery strategy — traffic weights, hold times, gate thresholds — is now a Git-committable, pull-request-reviewable object.

**Linkerd integration**: the Argo Rollouts Linkerd integration controller patches `HTTPRoute` backend weights at each step automatically — no manual `weight` field edits or PR merges required during a running rollout.

For full `Rollout` + `AnalysisTemplate` YAML, the step-by-step promotion sequence, AnalysisRun lifecycle, and the complete estate-scanner worked example: **`references/argo-rollouts-canary.md`**.

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
| GitOps-native gates | When Argo Rollouts is used, gate criteria live in `AnalysisTemplate` CRDs in Git — not CI scripts | Gate logic in a pipeline step that can be bypassed or modified without Git review |

---

## Anti-Patterns

- **Canarying a consumer group like an HTTP service** — attempting a "5% traffic" canary on a Redpanda consumer without a partition-level assignment either double-processes messages or silently canaries 0% of real traffic depending on which instance the rebalance favors. Use partition-share canary or blue-green.
- **No hold time** — advancing stages the instant the previous stage's weight applies gives the burn-rate windows no chance to accumulate signal; a 5-minute-old canary at 5% traffic has not generated enough requests to trust a burn-rate number yet.
- **Gates that only page** — an alert firing while the rollout controller (or the on-call, unprompted) keeps advancing weight anyway is theatre. The breach must halt and revert automatically, or a human must be the automation with an SLA tighter than the next stage's schedule.
- **Skipping the fleet tenant's own canary** — trusting the canary tenant's clean result to greenlight every other tenant at 100% ignores that tenant workloads differ; the fleet wave promotes the *digest*, not an exemption from re-canarying.
- **Canary weight left non-zero indefinitely** — a rollout stuck at 25% for weeks because nobody closed it out is neither rolled back nor rolled forward; it is undecided state that complicates the next release. Every canary terminates at 0% or 100%.
- **Gate criteria in CI, not in Git** — an `AnalysisTemplate` CRD in Git is peer-reviewed and cannot be bypassed without a PR; a threshold check in a pipeline step can be commented out, skipped, or overridden with a re-run. Gate criteria belong in Git.
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
[Reference to progressive-delivery for the strategy selection rationale]

## Workload Type
[Rollout CRD (Argo Rollouts) or Deployment + manual HTTPRoute PRs — with frugality justification]

## Traffic Route
charts/[service]/templates/canary-httproute.yaml
[Or: Rollout CRD spec in charts/[service]/templates/rollout.yaml]

## Stage Plan
| Stage | Weight | Hold time | Advance condition |

## Gate Rules
[When Argo Rollouts: AnalysisTemplate CRD path in Git]
prometheus/rules/canary-gate-[service]-[release].yaml
[Fast-burn, error-vs-baseline, latency-vs-baseline, freshness thresholds]

## Per-Tenant Wave
[Canary tenant result; fleet wave PR reference]

## Rollback Evidence
[Last auto-rollback drill: trigger, time-to-revert]

## Traceability
[SLO IDs (slo-definition); NFR IDs behind rollout risk tolerance]
```
