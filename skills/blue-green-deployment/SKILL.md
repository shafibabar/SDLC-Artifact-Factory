---
name: blue-green-deployment
description: >
  Teaches Blue-Green Deployment — when to choose it over Canary Deployment
  (schema cutovers, non-request-driven workloads, instant-rollback
  requirements), the two-Deployment-plus-Service-selector mechanics on
  Kubernetes, the GitOps environment-repo flip for per-tenant stamps, the
  database compatibility rule that both colours run against one schema via
  expand/contract, event-consumer handling that avoids double-consumption at
  cutover, the pre-flip verification gate, instant rollback by selector
  revert, and the transient 2x-capacity cost this strategy carries per
  service. Used by the platform-engineer during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, blue-green, progressive-delivery, rollback, cutover, expand-contract]
related: [canary-deployment, progressive-delivery, alerting-rules-design, cd-pipeline, go-migration]
---

# Blue-Green Deployment

## Purpose

**Blue-Green Deployment** runs two complete, independent instances of a service side by side — "blue" (currently live) and "green" (the new version) — and cuts traffic from one to the other atomically. Unlike `canary-deployment`'s gradual traffic shift, blue-green is binary: green is either receiving 0% or 100% of traffic, and the moment of cutover is a single, reversible switch.

That binary nature is blue-green's whole value and its whole cost. The value: rollback is a selector flip, not a redeploy — the previous version is still running, still warm, still provably correct, one edit away. The cost: two full copies of the service run simultaneously for the cutover window, so it is used where its properties are actually needed, not as a default. On this platform the default is `canary-deployment`; blue-green is the deliberate exception.

---

## When Blue-Green over Canary

| Situation | Choose | Why |
|---|---|---|
| Ordinary service release, request-driven, gradual exposure is safe | **Canary Deployment** | Gate on live SLO burn at small traffic share before full exposure; the platform default |
| Schema cutover that both versions cannot straddle indefinitely | **Blue-Green** | A bounded switch window is easier to reason about than a canary lingering at partial traffic against a migrating schema |
| Non-request-driven workload (batch job, scheduled reconciler, singleton consumer) | **Blue-Green** | There is no "traffic percentage" to shift — the unit of work is all-or-nothing per run |
| Instant, provable rollback is a hard requirement (compliance-sensitive cutover, high-blast-radius change) | **Blue-Green** | Rollback is a selector revert against an already-warm, already-verified target — no image pull, no readiness wait |
| Change is small, frequent, and traffic-shaped (typical feature release) | **Canary Deployment** | Canary's staged exposure catches regressions at 5% traffic rather than discovering them at 100% |
| Multi-day gradual validation desired (SLO soak across staged weights) | **Canary Deployment** | Blue-green's binary switch has no partial-exposure stage to soak at |

The decision is made once per release, recorded alongside the release plan — not improvised at deploy time. See `progressive-delivery` for the full when-blue-green-vs-canary decision framework, including intermediate strategies.

---

## Mechanics on Kubernetes

Two Deployments, one Service — the Service's `selector` is the cutover switch. The Deployment pair uses `slot: blue` / `slot: green` labels; changing one word in the Service selector is the entire cutover:

```yaml
apiVersion: v1
kind: Service
metadata: { name: compliance-engine }
spec:
  selector: { app: compliance-engine, slot: blue }   # flip to `green` = cutover
  ports: [{ port: 8080, targetPort: http }]
```

The cutover is a one-line diff to `spec.selector.slot` committed to the environment repo as a reviewed PR — no `kubectl edit`, no imperative script. Both Deployments run at full replica count through the verification window; green is fully warm (`/readyz` from `health-check-design` passing across all replicas) before a single production request reaches it.

For per-tenant stamps, the same diff applies per tenant directory in the environment repo — the cutover PR is what a reviewer actually reads. See `references/argo-rollouts-blue-green.md` for complete two-Deployment + Service YAML, per-tenant environment-repo diffs, and the full worked cutover sequence.

---

## Argo Rollouts blueGreen Strategy (GitOps-Native)

For services using GitOps-native progressive delivery, the imperative Service selector flip is replaced or supplemented by a `Rollout` CRD with `strategy.blueGreen`. This converts the procedural verification gate into a versioned, Prometheus-backed analysis that promotes or aborts automatically:

| `Rollout` field | Role |
|---|---|
| `activeService` | The stable Service receiving 100% of production traffic |
| `previewService` | The candidate Service — new pods run behind this Service, zero production traffic until promotion |
| `prePromotionAnalysis` | `AnalysisTemplate` run against the candidate *before* the selector flips; failure aborts and preserves the active version intact |
| `postPromotionAnalysis` | `AnalysisTemplate` run *after* promotion; failure triggers automatic rollback to the previous active Deployment |

`prePromotionAnalysis` and `postPromotionAnalysis` reference the same Prometheus success-rate and burn-rate queries that `alerting-rules-design` already defines as SLO expressions — no new metric infrastructure required. A passing analysis promotes automatically; a failing analysis rolls back automatically. Both outcomes appear in the `Rollout` status, visible in the environment repo's reconciled state and satisfying `cd-pipeline`'s GitOps audit requirement.

This pattern replaces the manual "Verification Gate Before Flip" checklist with a versioned `AnalysisRun` artifact reviewed in Git alongside the `Rollout` spec itself.

See `references/argo-rollouts-blue-green.md` for complete `Rollout` and `AnalysisTemplate` YAML, pass/fail threshold configuration, and integration with the per-tenant GitOps environment repo.

---

## Database Compatibility Rule — Expand/Contract, One Schema

Blue and green are never allowed to require different schemas. Both colours run against **the same PostgreSQL schema**, simultaneously, for the entire cutover window. This is the `go-migration` expand → migrate → contract discipline applied at the deployment layer:

1. **Expand** — the migration adds new columns/tables, nullable or defaulted, *before* either colour needs them. Both blue (old code) and green (new code) run cleanly against the expanded schema.
2. **Deploy green, verify, cut over** — green's code reads/writes the new shape; blue's code ignores the new columns.
3. **Contract** — only after green is stable and blue's Deployment is scaled to zero does a follow-up migration drop what blue depended on.

**Never dual-schema.** Rollback is only free if both colours can run against the same schema state. A schema rollback is never free once green has written data under the new shape. If a change cannot be expressed as expand/contract against one schema, it is not a blue-green candidate — escalate to the backend-engineer for a migration redesign.

---

## Event Consumer Handling — No Double-Consumption

For services that consume from Redpanda (entity-extractor, compliance-engine), **consumer group membership has no selector to flip**:

- **Green does not join the consumer group until cutover.** The green Deployment starts with its consumer loop paused (`feature-flag-design`'s kill-switch pattern — `pipeline.<service>.consumer.paused: true`) so it is running, health-checked, and provably ready but not pulling partitions.
- **At cutover**, the flip is two coordinated changes in the same PR: pause blue's consumer and unpause green — no window where both actively commit offsets on the same partitions.
- **Verify before unpausing**: green's non-consuming replicas prove readiness and can be smoke-tested against a shadow replay of recent messages without touching live partitions.

This is stricter than the HTTP case because Kafka/Redpanda consumer groups rebalance partitions across whichever members are active — there is no "0% vs 100%" at the broker level, only "in the group" or not.

---

## Verification Gate Before Flip

Green does not receive traffic until all checks pass. For services using the `Rollout` CRD, `prePromotionAnalysis` automates this gate. For services using the manual Service selector flip, run these checks before merging the cutover PR:

1. **Health** — `/readyz` green across all green replicas, sustained (not flapping) for a hold period.
2. **Schema compatibility** — expand migration applied and both colours observed reading/writing successfully.
3. **Smoke** — the tagged smoke subset (`go-e2e-test`) runs against green's debug Service before the live selector points at it.
4. **Dependency connectivity** — Vault Agent, PostgreSQL, Redpanda, and Linkerd mTLS all established on green.

---

## Instant Rollback = Selector Revert

Because blue never scales down until green proves itself in production, rollback is symmetric with cutover: revert the selector PR. No image pull (blue's pods are already running and warm), no migration to undo (expand/contract guarantees compatibility both directions within the window). For services using Argo Rollouts, `postPromotionAnalysis` failure triggers automatic rollback without a manual PR.

The bake window closes — blue scales to zero — only after production has run stably on green for the agreed period and the follow-up contract migration is scheduled.

---

## Cost Note — Transient 2x Capacity

Running two full-replica Deployments simultaneously doubles the service's compute footprint for the cutover-to-bake window. Frugality discipline:

- Scope the doubling to the one service cutting over — other services keep their normal single-Deployment footprint.
- Keep the bake window as short as release risk allows — doubled cost is time-bounded by design.
- Reserve blue-green for the decision-table situations — using it as the default would make 2x capacity the fleet's steady state.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Strategy fit | Blue-green chosen for schema cutover, non-request-driven, or instant-rollback need | Blue-green used as the default for ordinary releases |
| Both colours warm | Green fully deployed and probed healthy before any traffic/consumption | Green scaled up reactively after cutover starts |
| Single schema | Both colours run against one schema via expand/contract | Dual schemas, or contract step run before bake window closes |
| Consumer coordination | Green joins consumer group only at cutover, paused before | Both colours actively consuming the same partitions simultaneously |
| Verification gate | Health + schema + smoke + dependency pass; or Argo Rollouts prePromotionAnalysis passes | Selector flipped before green is proven |
| Rollback speed | Selector revert restores blue with no image pull, no migration; or postPromotionAnalysis auto-rollback fires | Rollback requiring redeploy or down-migration |
| Cost scoped | 2x capacity limited to the cutting-over service, time-bounded | Green left running indefinitely; blue-green as fleet-wide default |
| GitOps discipline | Flip is a reviewed PR to the Service manifest or Rollout CRD | Manual `kubectl edit` of the Service selector |

---

## Anti-Patterns

- **Blue-green as the default strategy** — 2x capacity for every deploy when `canary-deployment`'s gradual shift catches the same regressions at far less cost.
- **Dual-schema blue-green** — a separate database for green defeats rollback-is-free; one schema, expand/contract, always.
- **Consumer double-consumption** — flipping green's consumer on before blue's is paused processes every in-flight message twice; coordinate as one atomic PR.
- **Contract step run too early** — dropping old columns before the bake window proves green stable removes blue's ability to run, silently converting "instant rollback" to "no rollback."
- **Manual selector edits** — a `kubectl patch service` bypasses GitOps and leaves Git state lying about what's live.
- **Indefinite green** — both Deployments running indefinitely because nobody scheduled scale-down is 2x cost paid forever.
- **Blue-green for a partial-exposure need** — if the requirement is "validate at 10% traffic for three days," that is `canary-deployment`'s staged-weight model, not a binary switch.

---

## Output Format

Produces the cutover plan and manifests for a service release:

```markdown
---
name: blue-green-deployment-[service]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Blue-Green Deployment — [service]

## Strategy Decision
[Why blue-green over canary-deployment for this release — decision table row]

## Schema Compatibility
[Expand migration reference; contract migration scheduled date]

## Manifests
charts/[service]/templates/blue-green-deployment.yaml
deploy/clusters/tenants/[tenant]/[service]-service.yaml

## Verification Gate
[Checks run before flip; pass/fail evidence; or Argo Rollouts AnalysisTemplate reference]

## Cutover Sequence
| Step | Action | Verification |

## Bake Window and Rollback
[Bake duration; SLO alerts watched; rollback = selector revert or postPromotionAnalysis auto-rollback]

## Traceability
[go-migration reference; NFR IDs behind rollback requirement]
```
