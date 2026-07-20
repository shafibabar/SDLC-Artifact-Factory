---
name: environment-config
description: >
  Teaches Environment Parity and Configuration as Code — the environment set
  (kind-local, dev, staging, per-tenant production stamps), the rule that every
  environment runs the same chart and the same image digest with differences
  only in values, the taxonomy of build-time versus deploy-time versus
  runtime-flag configuration, the config/secret split (values in Git, secrets
  only via Vault Agent), and the promotion invariance check that proves the
  artifact never changed between environments. Used by the platform-engineer
  during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, environments, parity, configuration-as-code, values, promotion, tenants]
---

# Environment Config

## Purpose

Environments exist so that a release can be proven before a customer sees it. That proof is only valid if the thing being proven is the thing that ships — which is the whole of **Environment Parity**: every environment runs the *same chart* at the *same version* pointing at the *same image digest*, and differs **only** in values. The moment staging runs different code paths than production, staging stops testing production and starts testing itself.

The second law is **Configuration as Code**: every value that shapes an environment lives in the environment repo (`cd-pipeline`'s layout) and reaches the cluster through GitOps reconciliation. `kubectl edit` is drift, drift is an incident, and an environment whose true configuration lives partly in someone's shell history cannot be rebuilt — which makes it a disaster-recovery liability (`disaster-recovery-plan`).

---

## The Environment Set

| Environment | Purpose | Lifecycle | Who deploys |
|---|---|---|---|
| **kind-local** | Chart install tests in CI; engineer's laptop | Created and destroyed per run | CI (`helm-chart`'s kind gate), engineers |
| **dev** | First real-cluster convergence after merge | Long-lived, disposable — rebuilt from Git at will | Auto-commit from CI on green main |
| **staging** | Full-stack soak: nightly e2e/load suites, SLO soak, rollback and DR drills | Long-lived; mirrors production topology at reduced sizing | PR merged by platform-engineer |
| **tenant-\<id\> prod stamps** | One physically isolated production environment per tenant — own namespace/cluster, own PostgreSQL, own Redpanda, per `multi-tenancy-design` | Long-lived; stamped from the same OpenTofu module and charts | PR per fleet wave; Shafi approves first production promotion |

Two consequences of this set:

- **Staging is one environment, not one per tenant.** Tenants differ only in values (sizing, endpoints, tenant id), so one staging proves the chart for all of them. A per-tenant staging fleet would double cost for zero additional proof — frugality says no.
- **dev must be rebuildable from Git alone.** If deleting the dev cluster and re-bootstrapping the reconciler does not reproduce it exactly, Configuration as Code is already broken somewhere — dev is the cheap place to find out.

---

## Environment Parity — the Legitimate Differences

Same chart, same digest. What *may* differ between environments is a closed list, all of it values:

| Difference class | Examples | Why legitimate |
|---|---|---|
| **Sizing** | resource requests/limits, storage sizes, HPA bounds | Staging need not pay for production capacity |
| **Replicas** | replicaCount 1 in dev, 2 in staging, 3+ in prod | Availability is bought per environment |
| **Endpoints** | PostgreSQL host, Redpanda brokers, OTLP collector, ingress host | Each environment/tenant has its own physically isolated backing services |
| **Flags** | feature flags per `feature-flag-design`, log level, canary weights | Progressive Delivery is *configured* per environment, never coded per environment |
| **Identity** | `tenant.id`, environment label, alert routing receiver | Traceability and routing, not behaviour |

**Never a legitimate difference:** code paths. There is no `if env == "prod"` in any service, no staging-only binary, no debug build in dev. The Go binary cannot know or care which environment it is in beyond the configuration it is handed. A behaviour that must differ per environment is a **flag** (runtime, in values) — which means it is reviewable, diffable, and can be set identically in staging to rehearse production.

---

## Configuration Taxonomy — Where Does This Setting Belong?

Every configuration item is one of three kinds. Misfiling is the root of most "works in staging" incidents:

| Kind | Bound at | Changed by | Examples | Rule |
|---|---|---|---|---|
| **Build-time** | CI image build | New digest through the full pipeline | Go version, compiled dependencies, static assets | Never per-environment — parity dies otherwise |
| **Deploy-time** | Reconciler applies values | PR to the environment repo → rollout | endpoints, resources, replicas, ConfigMap env vars | The default home for configuration |
| **Runtime-flag** | Read live by the process | Flag change (ConfigMap reload or flag service, `feature-flag-design`) | kill-switches, release flags, log level | Only for what must change *faster than a rollout* |

Decision table:

| Question | Yes → |
|---|---|
| Does changing it require different compiled code? | Build-time — it is a new release, not config |
| Must it change without redeploying (incident kill-switch, rollout gate)? | Runtime-flag |
| Everything else | Deploy-time values — the boring, reviewable default |

The pressure to resist is runtime-flag inflation: every setting *could* be a live flag, but every live flag is state that Git only partially governs. Deploy-time is the default; runtime earns its place per `feature-flag-design`'s taxonomy.

---

## The Config/Secret Split

Configuration is public within the team; secrets are not, and the environment repo is the most-read repo in the company (`cd-pipeline`'s secrets boundary):

| Item | Lives in | Reaches the pod via |
|---|---|---|
| Non-secret config (endpoints, sizes, flags) | Environment repo values → ConfigMap | Env vars / mounted ConfigMap |
| Secrets (DB passwords, API keys, signing keys) | Vault, per tenant | **Vault Agent sidecar** injecting an in-memory volume — security-engineer's configuration; the chart mounts the pattern |

The test is mechanical: could this value appear in a public GitHub repo without an incident? Yes → values file. No → Vault, no exceptions, no "encrypted just this once" — the default posture is that nothing secret transits Git at all.

---

## Promotion Invariance Check

Parity is asserted by every doc and violated by one lazy rebuild — so it is *checked*, in CI, on every production promotion PR:

```bash
#!/usr/bin/env bash
# check-promotion-invariance.sh — gate on production promotion PRs
set -euo pipefail
service="$1"
staging=$(yq '.spec.values.image.digest' "deploy/clusters/staging/${service}.yaml")
for tenant_file in deploy/clusters/tenants/*/"${service}".yaml; do
  changed=$(git diff --name-only origin/main -- "$tenant_file")
  [ -z "$changed" ] && continue
  prod=$(yq '.spec.values.image.digest' "$tenant_file")
  if [ "$prod" != "$staging" ]; then
    echo "PARITY VIOLATION: $tenant_file promotes $prod but staging soaked $staging" >&2
    exit 1
  fi
done
```

A digest may not enter any production stamp unless it is the digest staging soaked. Combined with `helm-chart`'s schema (digest required, tags forbidden), this closes the rebuild loophole: what was tested is what runs, byte for byte.

---

## Worked Example — tenant-acme Values for estate-scanner

Everything tenant-specific for one service, in one reviewable file — and *only* legitimate difference classes appear:

```yaml
# deploy/clusters/tenants/tenant-acme/estate-scanner-values.yaml
tenant:
  id: acme                                      # identity — labels, metrics, alert routing
replicaCount: 3                                 # replicas — acme's volume tier
resources:
  requests: { cpu: 250m, memory: 256Mi }        # sizing — above the chart's base defaults
  limits:   { memory: 512Mi }
ingress:
  host: acme.app.example.com                    # endpoint — tenant's own host
postgres:
  host: estate-scanner-db.tenant-acme.svc.cluster.local   # endpoint — physically isolated DB
redpanda:
  brokers: redpanda.tenant-acme.svc.cluster.local:9092    # endpoint — tenant's own broker
flags:
  extractor.v2.enabled: false                   # flag — not yet in acme's wave (feature-flag-design)
env:
  LOG_LEVEL: info
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector.tenant-acme:4317
```

No image digest override beyond the promotion pointer, no template fork, no secret. The Vault Agent annotation and the chart version are fleet-uniform; `tenant-globex`'s file differs from this one only in the same five classes. Diffing two tenants' directories *is* the tenant comparison report — PM-readable by construction.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Environment set | kind-local/dev/staging/tenant stamps, each with a stated purpose | Ad-hoc environments; "test2" nobody can explain |
| Parity | Same chart version + same digest fleet-wide (within skew window) | Per-environment builds, forked charts, env-conditional code |
| Difference classes | Every env/tenant diff is sizing, replicas, endpoints, flags, or identity | Behavioural differences hidden in values; env checks in code |
| Configuration as Code | Every setting reaches clusters via the environment repo | `kubectl edit`, `--set` flags, console changes |
| Taxonomy applied | Each setting filed build/deploy/runtime with the decision table | Everything a live flag; or flags requiring redeploys |
| Secret split | Zero credentials in any values layer; Vault Agent only | Passwords in ConfigMaps or values files |
| Invariance checked | Digest-parity script gates every production promotion PR | Parity asserted in prose, unverified |
| Rebuildability | dev reproducible from Git alone, demonstrated | Environments that exist only as accumulated state |

---

## Anti-Patterns

- **The environment if-statement** — `if os.Getenv("ENV") == "prod"` means production runs code no other environment ever executed. The binary is environment-blind; only its inputs vary.
- **Staging as a museum** — staging pinned to an old chart "because the demo works" no longer rehearses anything. Staging tracks the promotion path or it is dead weight.
- **Config in two homes** — half the settings in values, half in a ConfigMap someone edits by hand. One home: the environment repo. The reconciler owns cluster writes.
- **The snowflake tenant** — "acme needed one small template tweak" forks the fleet; that tenant now misses every future fix. Tenant needs are values; template changes are fleet changes (`multi-tenancy-design`).
- **Per-tenant staging fleets** — testing forty staging environments to prove one chart. Parity means one staging suffices; the canary tenant wave (`cd-pipeline`) is the production-side safety net.
- **Secrets promoted through Git "temporarily"** — Git never forgets; one committed credential is a rotation, a history rewrite, and an incident. The Vault boundary is absolute.
- **Unverified parity** — a policy without the invariance check decays the first time someone hotfixes a tenant directly. Checks, not intentions.

---

## Output Format

Produces the environment configuration record for a product:

```markdown
---
name: environment-config-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Environment Configuration — [product]

## Environment Set
| Environment | Purpose | Sizing tier | Promotion trigger |

## Values Layout
deploy/clusters/{dev,staging}/…
deploy/clusters/tenants/[tenant-id]/…
[Per service: which keys are set at which layer]

## Difference Register
| Setting | Class (sizing/replicas/endpoints/flags/identity) | dev | staging | prod default |

## Configuration Taxonomy Decisions
| Setting | Kind (build/deploy/runtime) | Rationale |

## Invariance Gate
[Path to the promotion-parity check; CI job that runs it]

## Traceability
[multi-tenancy-design stamp model; NFR IDs behind sizing tiers]
```
