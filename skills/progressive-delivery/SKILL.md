---
name: progressive-delivery
description: >
  Teaches progressive delivery as a unified release risk-management discipline — the deploy/release distinction as its foundation, the decision framework for choosing canary vs blue-green vs feature-flag-only vs Argo Rollouts, when and how to combine strategies, the boundaries of what cannot be released progressively and the fallback strategies, and how to design a complete release strategy for a service. Used by the platform-engineer and backend-engineer to design service release strategies during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","progressive-delivery","canary","blue-green","feature-flags","argo-rollouts","release-strategy","risk-management"]
produces: release-strategy
domain: platform
status: stable
---

# Progressive Delivery

## The Foundation: Deploy vs. Release

**Deploy** means putting a new version of software into an environment — it may be running, dormant, or toggled off. **Release** means making that version available to some or all users. Big-bang releases that conflate the two are **forbidden in production** on this platform.

Progressive delivery is only possible because deploy and release are different activities. A binary can be deployed to 100% of instances while released to 0% of users (feature-flag-only), deployed to 5% of traffic while released to that 5% (canary), or deployed to a green environment while the blue environment still serves all traffic (blue-green). The separation is the discipline's foundation, established explicitly in *Continuous Delivery* (Humble, Farley, Ch. 10).

---

## Decision Framework — Choose ONE Primary Strategy

Select the primary strategy per service before deployment begins. Combining strategies requires explicit rationale (see below). When in doubt, canary is the default.

| Strategy | Use When | Tool | Cannot Use When |
|---|---|---|---|
| **Canary** (DEFAULT) | Stateless service, traffic can be split by percentage, SLO burn is the gating signal | Linkerd `HTTPRoute` + Argo Rollouts `Rollout` + `AnalysisTemplate` | Partitioned event consumers; schema is not backward-compatible |
| **Blue-Green** (EXCEPTION) | Schema cutover requiring both versions against one schema; non-request-driven workload; instant provable rollback required (previous version must stay warm) | Kubernetes Service selector flip + Argo Rollouts `Rollout` with `blueGreen` strategy | Cost is acceptable — blue-green requires 2x capacity during cutover window |
| **Feature-Flag-Only** | Change is guarded by a flag already deployed to 100% of instances; the release IS the flag-flip | OpenFeature / flags.json (see `feature-flag-design`) | The code is NOT yet deployed to production — flag-only requires the code to already be there |
| **Argo Rollouts** | Promotion and rollback criteria must be declarative, versionable, and GitOps-reconciled | Argo Rollouts `Rollout` CRD replacing `Deployment`; `AnalysisTemplate` + `AnalysisRun` | Team has not installed Argo Rollouts operator; workload type is not Deployment-equivalent |

Decision matrix with worked examples per bounded context type: `references/strategy-selection-guide.md`.

---

## Argo Rollouts — Key CRDs

When using Argo Rollouts (recommended for canary and blue-green when GitOps reconciliation of promotion criteria matters):

- **`Rollout`** — replaces `Deployment`; declares the strategy (canary steps or blue-green), references `AnalysisTemplate`
- **`AnalysisTemplate`** — defines a Prometheus/metric query and pass/fail threshold; versioned in Git alongside the Rollout
- **`AnalysisRun`** — per-rollout metric evaluation created by Argo Rollouts from the template; its pass/fail status gates promotion or triggers rollback

Complete Rollout + AnalysisTemplate YAML and wiring to this platform's Prometheus SLO rules: `references/argo-rollouts-cookbook.md`.

---

## Canary — Default Staged Progression

The standard four-stage progression (via `canary-deployment` for detailed gate thresholds):

| Stage | Canary weight | Minimum hold | Advances if |
|---|---|---|---|
| 1 | 5% | 15 min | Fast-burn gate clean for full hold |
| 2 | 25% | 30 min | Fast-burn + slow-burn gates clean |
| 3 | 50% | 30 min | Fast-burn + slow-burn + p99 latency gate clean |
| 4 | 100% | — | Terminal — canary becomes stable |

Any gate breach halts and reverts to 0% canary weight immediately. The progression is a ratchet — forward only when clean, never on a schedule.

---

## Blue-Green — When and How

Blue-green is an **exception**, not the default. Use it when:
1. A schema cutover requires both application versions to coexist against the same schema for a window (expand/contract cannot fully decouple this — see `go-migration`)
2. The workload is non-request-driven (no traffic percentage concept)
3. Instant provable rollback is required — the previous version must stay warm and switchable within seconds

Cost: 2x capacity during the cutover window. The Kubernetes Service selector flip is the rollback mechanism; it is tested and rehearsed before each release. See `blue-green-deployment` for the full protocol.

---

## Feature-Flag-Only — Release is the Flag-Flip

A feature-flag-only release has a specific precondition: **the code is already deployed to 100% of production instances and is reachable; only the flag state controls whether users see the new behaviour.** The flag-flip is the release.

This is the correct strategy for:
- UI/UX changes behind a flag that has already shipped to production
- Back-end behavioral changes where the new code path is deployed but inactive
- Percentage rollouts to user segments using the flag's targeting rules

The flag is not the deployment mechanism — it is the release mechanism. If the code is not yet deployed, this strategy does not apply. See `feature-flag-design` for the flag management protocol.

Step-by-step release procedure: `references/feature-flag-release-playbook.md`.

---

## Combining Strategies — Explicit Rationale Required

Combinations are allowed only when each layer's purpose is distinct and documented:

| Combination | When | Why |
|---|---|---|
| **Canary + Feature flag** | High-risk behavioral changes requiring maximum isolation | Canary limits traffic exposure (5% of requests); flag limits user exposure within that 5%. Double isolation. |
| **Blue-green + Feature flag** | Schema cutover complete (green at 100%), user-visible behavior still needs staged exposure | Green is running for all requests; flag controls which users see the new behavior within the fully-migrated codebase. |

No other combinations are defined. Any combination outside this table requires an ADR.

---

## Boundaries — What CANNOT Be Released Progressively

Two structural boundaries are hard limits:

**1. Partitioned Redpanda event consumers**
A Redpanda consumer group's partition assignment is all-or-nothing per partition. There is no "5% of messages" the way there is 5% of HTTP requests. Running two consumer versions simultaneously produces duplicate or missing events. **Strategy: blue-green** — pause v1, start v2 at 100% with consumer group offset preserved. If partition-level canary is required (assign the canary instance a bounded subset of partitions), this is a specialized technique documented in `canary-deployment`.

**2. Non-backward-compatible schema changes**
A canary writing under a new schema while stable writes under the old schema is two schemas in flight simultaneously. **Strategy: expand/contract migration first** (`go-migration`) — expand the schema to tolerate both versions, complete the canary, then contract. The canary's code rollout can still be gradual; the schema itself must straddle both versions for the entire rollout window.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Deploy/release separation | Every production release uses a mechanism that separates deploy from release | Big-bang deploy-and-release in one step |
| Strategy selection justified | Strategy choice documented against the decision table | Strategy chosen by habit or team preference without applying criteria |
| Canary is the default | Ordinary stateless services use canary unless a documented exception applies | Blue-green as default for all services |
| Boundaries respected | Partitioned consumers use blue-green; schema changes ride expand/contract first | Progressive traffic split attempted on a consumer group or incompatible schema |
| Argo Rollouts used when criteria met | GitOps-reconciled promotion criteria in `AnalysisTemplate` when declarative gating is required | Rollback logic implemented as a pipeline script outside Git version control |

---

## Anti-Patterns

- **Big-bang deploy-and-release**: deploying to 100% and releasing to 100% simultaneously, removing the ability to stop and revert without a full rollback
- **Canary on a consumer group**: attempting percentage-of-traffic canary on a Redpanda consumer group — the partition model doesn't support it; use blue-green or partition-share canary
- **Feature flag as a deployment mechanism**: shipping the flag before the code, then using the flag to "activate" code that isn't yet in production
- **Blue-green as the safe default**: defaulting to blue-green for every service because it "feels safer" — it costs 2x capacity and the instant rollback benefit only matters when it's actually needed
- **Combining strategies without rationale**: running canary and blue-green for the same release because one team member prefers each — combinations must have a documented purpose

---

## Output Format

```markdown
---
name: release-strategy-[service]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Release Strategy — [service]

## Strategy Selection
[Primary strategy chosen, criterion from decision table that applies]

## Rationale for Combination (if any)
[Or: N/A — single strategy]

## Boundary Check
[Consumer type: stateless HTTP / partitioned consumer → strategy confirmed]
[Schema impact: backward-compatible / expand-contract required → status]

## Staged Plan
[For canary: stage weights, hold times, gate queries]
[For blue-green: cutover window, rollback test date]
[For feature-flag: flag name, targeting rules, flip procedure]

## Rollback Procedure
[Canary: revert to 0% weight / Argo Rollouts abort command]
[Blue-green: Service selector revert]
[Feature flag: flag-off revert, drain window]

## Traceability
[SLO IDs (slo-definition); NFR IDs; ADR reference if combination used]
```
