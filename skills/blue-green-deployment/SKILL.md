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
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, blue-green, progressive-delivery, rollback, cutover, expand-contract]
---

# Blue-Green Deployment

## Purpose

**Blue-Green Deployment** runs two complete, independent instances of a service side by side — "blue" (currently live) and "green" (the new version) — and cuts traffic from one to the other atomically. Unlike `canary-deployment`'s gradual traffic shift, blue-green is binary: green is either receiving 0% or 100% of traffic, and the moment of cutover is a single, reversible switch.

That binary nature is blue-green's whole value and its whole cost. The value: rollback is a selector flip, not a redeploy — the previous version is still running, still warm, still provably correct, one edit away. The cost: two full copies of the service run simultaneously for the cutover window, so it is used where its properties are actually needed, not as a default. On this platform the default is `canary-deployment`; blue-green is the deliberate exception.

---

## When Blue-Green over Canary

| Situation | Choose | Why |
|---|---|---|
| Ordinary service release, request-driven, gradual exposure is safe | **Canary Deployment** (`canary-deployment`) | Gate on live SLO burn at small traffic share before full exposure; the default |
| Schema cutover that both versions cannot straddle indefinitely | **Blue-Green** | A bounded switch window is easier to reason about than a canary that lingers at partial traffic against a migrating schema |
| Non-request-driven workload (batch job, scheduled reconciler, singleton consumer) | **Blue-Green** | There is no "traffic percentage" to shift — the unit of work is all-or-nothing per run |
| Instant, provable rollback is a hard requirement (compliance-sensitive cutover, high-blast-radius change) | **Blue-Green** | Rollback is a selector revert against an already-warm, already-verified target — no image pull, no readiness wait |
| Change is small, frequent, and traffic-shaped (typical feature release) | **Canary Deployment** | Canary's staged exposure catches regressions at 5% traffic instead of discovering them at 100% |
| Multi-day gradual validation desired (SLO soak across staged weights) | **Canary Deployment** | Blue-green's binary switch has no partial-exposure stage to soak at |

The decision is made once per release, recorded alongside the release plan — not improvised at deploy time.

---

## Mechanics on Kubernetes

Two Deployments, one Service, the Service's `selector` is the cutover switch:

```yaml
# templates blue-green-deployment.yaml — two Deployment objects, same chart
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliance-engine-blue
  labels: { app: compliance-engine, slot: blue }
spec:
  replicas: 3
  selector: { matchLabels: { app: compliance-engine, slot: blue } }
  template:
    metadata: { labels: { app: compliance-engine, slot: blue } }
    spec:
      containers:
        - name: compliance-engine
          image: "ghcr.io/acme/data-estate/compliance-engine@sha256:aaa1…"   # currently live
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliance-engine-green
  labels: { app: compliance-engine, slot: green }
spec:
  replicas: 3
  selector: { matchLabels: { app: compliance-engine, slot: green } }
  template:
    metadata: { labels: { app: compliance-engine, slot: green } }
    spec:
      containers:
        - name: compliance-engine
          image: "ghcr.io/acme/data-estate/compliance-engine@sha256:bbb2…"   # candidate
---
apiVersion: v1
kind: Service
metadata: { name: compliance-engine }
spec:
  selector: { app: compliance-engine, slot: blue }    # ← THE cutover: change to `green`, PR-reviewed
  ports: [{ port: 8080, targetPort: http }]
```

The cutover is a one-line diff to `spec.selector.slot` in the Service manifest, applied by the reconciler exactly as any other change (`cd-pipeline`) — no `kubectl edit`, no imperative script holding state. Both Deployments run at full replica count through the verification window; green is fully warm (probes green, `health-check-design`'s `/readyz` passing across all replicas) before a single production request reaches it.

### GitOps environment-repo flip for per-tenant stamps

Under the per-tenant fleet model, the same mechanics apply per tenant directory, and the cutover PR is what a reviewer actually reads:

```diff
# deploy/clusters/tenants/tenant-acme/compliance-engine-service.yaml
 spec:
   selector:
     app: compliance-engine
-    slot: blue
+    slot: green
```

That diff is the entire cutover — reviewable, revertible by a second PR, and auditable in `git log` exactly as `cd-pipeline` requires of every production change.

---

## Database Compatibility Rule — Expand/Contract, One Schema

Blue and green are never allowed to require different schemas. Both colours run against **the same PostgreSQL schema**, simultaneously, for the entire cutover window — there is no "green's database" and "blue's database." This is the backend-engineer's `go-migration` expand → migrate → contract discipline applied at the deployment layer:

1. **Expand** — the migration adds new columns/tables, nullable or defaulted, deployed *before* either colour needs them. Both blue (old code) and green (new code) run cleanly against the expanded schema.
2. **Deploy green, verify, cut over** — with the schema already expanded, green's code can read/write the new shape; blue's code simply ignores the new columns it doesn't know about.
3. **Contract** — only after green is stable and blue's Deployment is scaled to zero does a follow-up migration drop the columns/tables blue depended on and green no longer needs.

**Never dual-schema.** Standing up a second database for green "to be safe" breaks the one property blue-green is supposed to guarantee — that rollback is free — because a schema rollback is never free once green has written data under the new shape. If a change cannot be expressed as expand/contract against one schema, it is not a candidate for blue-green cutover at all; escalate to the backend-engineer for a migration redesign.

---

## Event Consumer Handling — No Double-Consumption

For services that consume from Redpanda (entity-extractor, compliance-engine), blue-green needs one more rule beyond the Service selector, because **consumer group membership has no selector to flip**:

- **Green does not join the consumer group until cutover.** The green Deployment starts with its consumer loop paused (the ops kill-switch pattern from `feature-flag-design` — `pipeline.<service>.consumer.paused: true` in green's values) so it is running, health-checked, and provably ready, but not pulling partitions.
- **At cutover**, the flip is two coordinated changes in the same PR: scale blue's consumer to zero (or flip blue's pause flag on) and unpause green — never a window where both are actively committing offsets on the same partitions, which would double-process every message between the two commits.
- **Verify before unpausing**: green's non-consuming replicas still prove readiness (`/readyz`, dependency connectivity) and can be smoke-tested against a shadow/replay of recent messages if the risk warrants it, without touching the live partitions.

This is stricter than the HTTP Service case precisely because Kafka/Redpanda consumer groups rebalance partitions across *whichever* members are active — there is no "0% vs 100%" concept at the broker level, only "in the group" or "not."

---

## Verification Gate Before Flip

Green does not receive traffic (or unpause its consumer) until every check in this gate is green — mirroring `cd-pipeline`'s post-deploy verification, run *before* cutover instead of after:

1. **Health** — `/readyz` green across all green replicas, sustained (not flapping) for a hold period.
2. **Schema compatibility** — the expand migration has been applied and both blue and green have been observed reading/writing successfully.
3. **Smoke** — the tagged smoke subset (`go-e2e-test`) runs directly against green's Service (a temporary debug Service or port-forward, never through the live selector) before the live selector ever points at it.
4. **Dependency connectivity** — green's Vault Agent sidecar has issued credentials, PostgreSQL and Redpanda connections are established, Linkerd mTLS is established (mesh identity visible in `linkerd viz`).

Only after all four pass does the selector-flip PR merge.

---

## Instant Rollback = Selector Revert

Because blue never scales down until green has proven itself in production (typically a bake window — see worked example), rollback is symmetric with cutover: revert the selector PR.

```diff
# rollback — git revert of the cutover commit
 spec:
   selector:
     app: compliance-engine
-    slot: green
+    slot: blue
```

No image pull (blue's pods are already running and warm), no readiness wait, no migration to undo (expand/contract guarantees compatibility both directions within the window). This is the property `canary-deployment` cannot match at the same speed — a canary rollback still has to scale the new version down and old version up across whatever weight it was caught at; blue-green rollback is a single Service object edit.

The bake window closes — blue scales to zero — only after production has run stably on green for the agreed period (per release risk, typically hours to a few days) and the follow-up **contract** migration is scheduled.

---

## Cost Note — Transient 2x Capacity, Per Service Not Fleet-Wide

Running two full-replica Deployments simultaneously means the service's compute footprint doubles for the cutover-to-bake window. Frugality discipline:

- **Scope the doubling to the one service cutting over**, never the whole fleet — other services are unaffected and keep their normal single-Deployment footprint.
- **Keep the bake window as short as the release risk allows** — the doubled cost is time-bounded by design; a green Deployment left running "just in case" for weeks is paying full 2x cost for a rollback guarantee that should have already converted to confidence.
- **Reserve blue-green for the situations in the decision table** — using it as the default strategy for every release would make 2x capacity the fleet's steady state, which is precisely why `canary-deployment` (gradual, no full-duplicate footprint) is the default and blue-green is the exception.

---

## Worked Example — Cutover Sequence for compliance-engine

Cutting over `compliance-engine` to a release that expands the `classification_findings` table with a new `evidence_ref` column (needed by the new SIEM-export capability) and changes the `ClassifyDataAsset` command handler:

1. **Expand migration** ships ahead of the cutover, through the normal `go-migration` pipeline: `evidence_ref TEXT NULL` added, backfill job scheduled separately. Blue (still running old code) ignores the new column entirely.
2. **Green Deployment created** — `compliance-engine-green`, image digest for the new release, `slot: green`, consumer pause flag `true`. Both blue and green now run against the expanded schema.
3. **Verification gate runs** — readyz green across 3 green replicas for 10 minutes; smoke test hits green's debug Service directly (`PATCH /v1/data-assets/{id}/classification` against a fixture tenant, asserts `evidence_ref` populated); Vault Agent and Linkerd identity confirmed.
4. **Cutover PR merges** — Service selector flips to `green`; in the same PR, green's consumer-pause flag flips to `false` and blue's flips to `true`. Reconciler applies both within one interval — no window with both colours actively consuming.
5. **Bake window** — 24 hours production traffic on green, `slo-definition`'s availability/latency SLIs and the correctness SLI watched via `alerting-rules-design`'s burn-rate alerts (any fast-burn page triggers the selector-revert rollback immediately, no new deploy required).
6. **Contract migration** scheduled after bake completes cleanly: blue's Deployment is scaled to zero and deleted; a follow-up migration (separately reviewed) drops nothing here since `evidence_ref` is additive, but for a genuinely destructive contract step this is where old columns/tables are finally removed.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Strategy fit | Blue-green chosen for schema cutover, non-request-driven, or instant-rollback need | Blue-green used as the default for ordinary releases |
| Both colours warm | Green fully deployed and probed healthy before any traffic/consumption | Green scaled up reactively after cutover starts |
| Single schema | Both colours run against one schema via expand/contract | Dual schemas, or a contract step run before the bake window closes |
| Consumer coordination | Green joins the consumer group only at cutover, paused before | Both colours actively consuming the same partitions simultaneously |
| Verification gate | Health + schema + smoke + dependency checks pass before flip | Selector flipped before green is proven |
| Rollback speed | Selector revert restores blue with no image pull, no migration | Rollback requiring redeploy or down-migration |
| Cost scoped | 2x capacity limited to the cutting-over service, time-bounded | Green left running indefinitely; blue-green as fleet-wide default |
| GitOps discipline | Flip is a reviewed PR to the Service manifest | Manual `kubectl edit` of the Service selector |

---

## Anti-Patterns

- **Blue-green as the default strategy** — reaching for two-full-copies-and-a-switch for routine feature releases pays 2x capacity for every deploy when `canary-deployment`'s gradual shift would catch the same regressions at 5% cost. Blue-green earns its place per the decision table.
- **Dual-schema blue-green** — standing up a separate database for green defeats the entire purpose: rollback is no longer free, and the two colours can silently diverge on data. One schema, expand/contract, always.
- **Consumer double-consumption** — flipping green's consumer on before blue's is paused processes every in-flight message twice; without idempotent handlers (`opentelemetry-instrumentation`/backend-engineer's Idempotency discipline) this corrupts derived state. Coordinate the flip as one atomic PR.
- **The contract step run too early** — dropping old columns/tables before the bake window proves green stable removes blue's ability to run at all, which quietly converts an "instant rollback" strategy into "no rollback." Contract only after bake.
- **Manual selector edits "just this once"** — a `kubectl patch service` to test the flip bypasses the same GitOps guarantee every other change on this platform relies on, and leaves the Git state lying about what's live.
- **Indefinite green** — leaving both Deployments running because nobody scheduled the scale-down is 2x cost paid forever for a decision that was already made. The bake window has an end date from the day the cutover PR is written.
- **Blue-green for a partial-exposure need** — using blue-green when the actual requirement is "validate at 10% traffic for three days" reaches for the wrong tool; that is `canary-deployment`'s staged-weight-with-hold-time model, not a binary switch.

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
[Checks run before flip; pass/fail evidence]

## Cutover Sequence
| Step | Action | Verification |

## Bake Window and Rollback
[Bake duration; SLO alerts watched; rollback = selector revert, drilled on date]

## Traceability
[go-migration reference; NFR IDs behind rollback requirement]
```
