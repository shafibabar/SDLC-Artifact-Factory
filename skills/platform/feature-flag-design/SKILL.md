---
name: feature-flag-design
description: >
  Teaches Feature Flag design and lifecycle — the four-way taxonomy (release,
  ops/kill-switch, experiment, entitlement) with a distinct lifecycle per type,
  the flag-debt rule that every release flag has an owner and a removal date,
  a frugal implementation ladder from ConfigMap-reloaded static flags to a
  self-hosted OpenFeature-compatible provider when runtime targeting is
  required, the rule that server-side evaluation is authoritative and client
  flags are UX hints only, the CI flag matrix that tests both branches of a
  flag, and the kill-switch pattern for pausing pipeline consumers without a
  deploy. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, feature-flags, progressive-delivery, kill-switch, entitlements, openfeature]
---

# Feature Flag Design

## Purpose

A **Feature Flag** decouples *deploying* code from *releasing* behaviour: the digest ships through the one path (`ci-pipeline`, `cd-pipeline`) and a flag decides, at runtime, whether a code path is live. That decoupling is the entire value — it also creates a liability if left unmanaged, because every live flag is a branch point that state can silently diverge across, and every flag that outlives its purpose is a piece of code nobody dares delete.

This skill governs flags as a typed, owned, expiring inventory — not a scattered collection of booleans. It is deliberately narrow: `canary-deployment` and `blue-green-deployment` own *traffic* shifting between versions; this skill owns *behavioural* toggling within a running version. The two compose (a canary-scoped release flag, below) but are not the same mechanism.

---

## The Flag Taxonomy

Four kinds, and they behave nothing alike. Filing a flag under the wrong kind is the root cause of most flag debt.

| Kind | Purpose | Lifetime | Who decides its value | Example |
|---|---|---|---|---|
| **Release flag** | Ship code dark, release it independently of deploy | **Temporary** — days to a few weeks | Platform-engineer, per rollout plan | `extractor.v2.enabled` |
| **Ops / kill-switch** | Pause or degrade a subsystem during an incident without a deploy | Permanent infrastructure, rarely *on* | On-call, during an incident | `pipeline.entity-extractor.consumer.paused` |
| **Experiment flag** | A/B or staged comparison to inform a product decision | Temporary — bounded by the experiment | Product decision (Shafi), platform-engineer implements | `ranking.model-b.enabled` |
| **Entitlement flag** | What a tenant's plan or contract includes | **Permanent** product configuration | Sales/product, stored as tenant config, not a "flag" in spirit | `entitlement.advanced-classification` |

Two of the four are meant to live forever (ops, entitlement); two are meant to die (release, experiment). Confusing the pairs is the failure mode: a release flag treated as permanent becomes an untestable maze of `if`s; an entitlement flag treated as disposable gets accidentally deleted along with a tenant's paid feature.

---

## Lifecycle per Type

### Release flags — the flag-debt rule

Every release flag is created with three fields, non-optional:

```yaml
# flags/release/extractor-v2-enabled.yaml
key: extractor.v2.enabled
kind: release
owner: platform-engineer          # accountable for removal
created: 2026-07-20
removal_date: 2026-08-10          # ≤ 3 weeks out — hard default
removal_issue: PLAT-482           # tracked; CI fails the flag inventory check without it
default: false
```

The rule: **a release flag with no owner and no removal date does not merge.** At the removal date, the flag is deleted from code and from every environment's values — not "set to true forever." Deleting it means picking the winning branch and removing the loser; a release flag that survives past 100% rollout without deletion is flag debt, and the CI flag-inventory check (below) fails the build on any release flag past its `removal_date` still present in the codebase.

### Ops / kill-switches

Permanent, and *expected* to sit `false`/`off` almost always. No removal date — their whole value is being there, tested, the one time an incident needs them. Reviewed quarterly (with `alerting-rules-design`'s monthly alert review) for two things only: does it still map to a real subsystem, and was it drilled recently enough that the on-call trusts it.

### Experiment flags

Temporary like release flags, but the exit criterion is a decision, not a percentage — the experiment ends when the result is read, not when rollout completes. Owner is the platform-engineer; the decision that closes it is Shafi's or the product owner's, recorded as an ADR reference in the flag's removal record.

### Entitlement flags

Not really "flags" in the disposable sense — they are tenant configuration that happens to gate code paths, and they live exactly as long as the tenant's contract does. They belong in the **per-tenant values layer** (`environment-config`'s difference-class table, row "flags"), never in a central flag service's default-off inventory, because their value is tenant-specific truth, not a rollout state:

```yaml
# deploy/clusters/tenants/tenant-acme/compliance-engine-values.yaml (extract)
flags:
  entitlement.advanced-classification: true    # acme's contracted tier
  entitlement.export-to-siem: false             # not on acme's plan
```

---

## The Frugal Implementation Ladder

Do not reach for a flag service until static configuration genuinely cannot do the job. Two rungs:

| Rung | Mechanism | Fits | Cost |
|---|---|---|---|
| **1 — Static, per-environment/tenant** | Flag value in the environment repo's values (`environment-config`'s runtime-flag row) → ConfigMap → process reads it at startup or on ConfigMap-reload (SIGHUP or file-watch) | Release, entitlement, and most ops flags — anything targeted by environment/tenant, not by user or request | Zero — it is Configuration as Code already |
| **2 — Runtime targeting service (OpenFeature-compatible, self-hosted)** | A self-hosted flag provider (e.g. `flagd`) implementing the OpenFeature spec, queried per-request/per-user for percentage rollout or user-attribute targeting | Experiment flags needing user-level bucketing; release flags needing percentage ramps *below* the granularity of a tenant wave | flagd is a single lightweight binary — self-hosted, open-source, no paid SaaS |

Decision table:

| Question | Rung 1 suffices? |
|---|---|
| Does the flag only ever need to differ by tenant or environment? | Yes — static values |
| Does it need to differ by individual user, or by a percentage *within* one tenant? | No — Rung 2 |
| Does it need to change without a values-repo PR merge (true kill-switch speed)? | Depends — see kill-switch pattern below; still Rung 1 with a faster reload path |

**Never**: a paid feature-flag SaaS at this scale. `flagd` plus the environment repo covers every case in the taxonomy above; a hosted flag platform is a recurring line-item for a problem two open-source primitives already solve. If a future need (true progressive percentage ramps across millions of end users, not tenants) outgrows Rung 2, that is an ADR, not a default.

---

## Evaluation Rule: Server-Side Is Authoritative

Mirrors the frontend-engineer's ABAC posture exactly, for the same reason: anything evaluated in a browser is a UX hint an attacker can flip in devtools, not a security or business boundary.

| Where | Role |
|---|---|
| **Server (Go services)** | Authoritative. Every gated behaviour — API response shape, event published, classification model invoked — is decided server-side, on every request, never cached client-side as truth |
| **Client (React)** | Reads the *server's* resolved flag state (returned in the API response or a `/v1/flags` resolve call) to decide what UI to render. Never evaluates targeting logic itself; never trusts a client-stored flag value to gate a server action |

A client that hides an "Advanced Classification" button because a flag is off is UX. The server rejecting the underlying API call regardless of what the client sent is the actual gate. This is the same shape as `access-control-model`'s ABAC boundary — flags are not a second security system, they follow the same rule.

---

## Testing Both Paths — the CI Flag Matrix

A flag that is only ever tested in its default state is half-tested; the day it flips, the untested branch ships blind. The test-strategist's suite runs the flag matrix for every active release/experiment flag:

```yaml
# .github/workflows/ci.yml (extract — flag matrix job)
strategy:
  matrix:
    extractor_v2_enabled: [true, false]
steps:
  - run: |
      FLAG_EXTRACTOR_V2_ENABLED=${{ matrix.extractor_v2_enabled }} \
        go test ./... -run TestExtractorPipeline -tags flagmatrix
```

The flag inventory itself is checked, not just the code paths:

```bash
#!/usr/bin/env bash
# check-flag-inventory.sh — CI gate on every PR touching flags/
today=$(date +%F)
for f in flags/release/*.yaml flags/experiment/*.yaml; do
  removal=$(yq '.removal_date' "$f")
  owner=$(yq '.owner' "$f")
  [ "$owner" = "null" ] && { echo "FLAG DEBT: $f has no owner" >&2; exit 1; }
  if [[ "$removal" < "$today" ]]; then
    echo "FLAG DEBT: $f is past its removal_date ($removal) and still present" >&2
    exit 1
  fi
done
```

Ops and entitlement flags are exempt from the removal check (they are meant to persist) but must still appear in the inventory with an owner, so an incident responder can find every kill-switch that exists.

---

## The Kill-Switch Pattern — Pausing a Pipeline Without a Deploy

The canonical ops flag: pause a Redpanda consumer group during an incident (bad message shape flooding the DLQ, a downstream dependency down) without touching the deploy pipeline.

```go
// entity-extractor consumer loop — reads the ops flag on each poll interval
for {
    if flags.Bool(ctx, "pipeline.entity-extractor.consumer.paused", false) {
        metrics.ConsumerPaused.Set(1)
        time.Sleep(pauseCheckInterval)   // 5s — fast enough to feel like a switch
        continue
    }
    metrics.ConsumerPaused.Set(0)
    processBatch(ctx)
}
```

Flip path in an incident: edit the ConfigMap value via a PR to the environment repo (still GitOps — even a kill-switch does not bypass `cd-pipeline`'s "no `kubectl apply`" rule), or, if the incident cannot wait for a reconciliation interval, a break-glass `kubectl patch configmap` executed by the on-call and immediately followed by the matching PR so Git catches up to reality within the hour. The break-glass path is drift, and drift is alerted per `cd-pipeline` — the alert firing is expected and accepted for the duration of an active incident, not silenced.

This is why ops flags live at Rung 1 (static, ConfigMap-reloaded): the fast poll interval above gives sub-10-second reaction time without needing a targeting service, and the value's home is still the environment repo — auditable, revertible, no separate system of record for "what did we turn off during the incident."

---

## Worked Example — Canary-Scoped Release Flag for a New Extractor Model

`entity-extractor` is getting a new entity-extraction model (v2). The rollout combines a **release flag** (behavioural: which model runs) with `canary-deployment`'s **tenant wave** (deployment: which tenants run the new binary at all) — two different axes, composed deliberately so the flag can be flipped back instantly if the model regresses, without waiting on a redeploy.

```yaml
# flags/release/extractor-v2-enabled.yaml
key: extractor.v2.enabled
kind: release
owner: platform-engineer
created: 2026-07-20
removal_date: 2026-08-10
removal_issue: PLAT-482
default: false
description: >
  Routes document extraction to the v2 model when true. Canary-tenant only
  until PLAT-482 evaluation completes; see canary-deployment worked example
  for the accompanying traffic wave.
```

```yaml
# deploy/clusters/tenants/tenant-canary/entity-extractor-values.yaml
flags:
  extractor.v2.enabled: true      # canary tenant runs v2 behaviour
```

```yaml
# deploy/clusters/tenants/tenant-acme/entity-extractor-values.yaml
flags:
  extractor.v2.enabled: false     # unaffected until PLAT-482 promotes the wave
```

Both tenants run the **same image digest** — `environment-config`'s parity rule is intact; only the flag value differs. If v2 regresses extraction accuracy (caught by the correctness SLI from `slo-definition`), the fix is a values PR flipping the flag back to `false` for the canary tenant — no rollback, no redeploy, seconds not minutes. When the model is proven and rolled to the full fleet, `extractor.v2.enabled` is deleted from code (the `if` collapses to always-v2) on `removal_date`, and PLAT-482 closes.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Taxonomy applied | Every flag filed as release/ops/experiment/entitlement with the matching lifecycle | Undifferentiated boolean list |
| Flag debt rule | Every release/experiment flag has owner + removal date, enforced in CI | Flags with no expiry, no accountable owner |
| Entitlement placement | Entitlement flags live in per-tenant values, not a central default-off inventory | Entitlements modeled as ordinary release flags |
| Implementation ladder | Static values by default; targeting service only when user/percentage targeting is genuinely needed | Flag service adopted for tenant-only differences |
| Frugality | Self-hosted OpenFeature-compatible provider (`flagd`) if Rung 2 is needed; no paid SaaS | Paid flag platform at MVP scale |
| Server-authoritative | Server evaluates and enforces; client renders based on server-resolved state | Client-side targeting logic gating a server action |
| Tested both paths | CI flag matrix runs both branches of every active release/experiment flag | Only the default state is ever tested |
| Kill-switch speed | Ops flags reload fast enough (seconds) to matter in an incident, still via GitOps | Kill-switch requiring a full redeploy to flip |
| Removal enforced | Flag inventory check fails CI on any flag past its removal date | Flags accumulating indefinitely past rollout |

---

## Anti-Patterns

- **The permanent release flag** — "just leave it, it's not hurting anything" is how a codebase accumulates a hundred `if`s nobody remembers the meaning of. Every release flag has a death date from the day it is born.
- **Client-side entitlement enforcement** — hiding a paid feature in the UI while the API still serves it to any authenticated user is a revenue leak dressed as a feature flag. The server gate is the entitlement; the client hint is decoration.
- **Flag-as-branch-strategy** — nesting release flags to avoid ever merging to main turns the flag system into an unmerged branch with extra steps, and the flag matrix combinatorially explodes. Merge to main; gate behaviour, not branches.
- **Central targeting service for tenant-only differences** — running `flagd` to decide something that is purely a function of `tenant.id` reinvents `environment-config`'s values layer with an extra network hop and an extra thing to keep available during an incident.
- **The kill-switch nobody drills** — an ops flag wired in code but never exercised is a hope, not a capability; when the incident arrives, nobody trusts flipping it. Ops flags belong in the DR/runbook drill rotation (`disaster-recovery-plan`, `runbook-authoring`).
- **Experiment flags with no decision date** — an A/B test that "runs a while longer" never concludes because nobody owns reading the result. The exit criterion is a decision, scheduled like any other deliverable.
- **Paid flag SaaS for a Han-Solo-scale fleet** — a monthly line item to toggle booleans that ConfigMaps and one open-source binary already handle. Justify the spend in an ADR or don't make it.

---

## Output Format

Produces the flag inventory and lifecycle record for a product:

```markdown
---
name: feature-flag-design-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Feature Flag Design — [product]

## Implementation Ladder Decision
[Rung 1 only, or Rung 1 + flagd — rationale]

## Flag Inventory
| Key | Kind | Owner | Created | Removal date / N-A | Removal issue | Default |

## Evaluation Boundary
[Server-authoritative statement; client-hint contract]

## CI Flag Matrix
[Which flags are matrixed; test tags; inventory-check script path]

## Kill-Switch Registry
| Flag | Subsystem it pauses/degrades | Reload path | Last drilled |

## Traceability
[Rollout plan / canary-deployment reference; ADR for any Rung 2 adoption]
```
