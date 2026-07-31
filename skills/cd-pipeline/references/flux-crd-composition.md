# Flux CRD Composition Reference

This document is the extended reference for `cd-pipeline`'s Flux implementation.
It is loaded when the body directs the platform-engineer to look here for field-level
detail, YAML examples, or worked scenarios.

---

## The Three CRDs and Their Roles

Flux decomposes the reconciliation concern into separate controllers, each managing
one CRD. They compose into a pipeline by referencing each other via `sourceRef`.

### GitRepository

**API group:** `source.toolkit.fluxcd.io/v1`

Polls a Git repository on a configurable interval, fetches the target commit
(branch, tag, or exact SHA), and publishes the commit tree as a named artifact
that downstream controllers consume. It does not apply anything to the cluster —
its only job is fetching and exposing.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-repo
  namespace: flux-system
spec:
  interval: 1m          # how often to poll for new commits
  url: https://github.com/acme/data-estate
  ref:
    branch: main        # or tag: v1.4.0 / commit: sha256:...
  secretRef:
    name: platform-repo-deploy-key   # read-only SSH deploy key, per cluster
```

**One GitRepository per source repo per cluster.** In a per-tenant fleet, each
tenant cluster has its own `GitRepository` pointing at the same platform repo URL
with its own deploy key — isolation is at the key level, not the source level.

---

### Kustomization

**API group:** `kustomize.toolkit.fluxcd.io/v1`

Takes a path within a `GitRepository` artifact, runs `kustomize build` on it
(or a plain directory apply if no `kustomization.yaml` is present), and applies
the resulting manifests to the cluster. It is the top-level reconciliation unit
for an environment.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: dev-environment
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: platform-repo
  path: ./deploy/clusters/dev        # the directory this Kustomization owns
  prune: true                        # delete resources removed from the path
  wait: true                         # wait for all applied resources to be ready
  timeout: 3m
```

**Usage in this platform:**
- One `Kustomization` per environment directory (`dev`, `staging`,
  `tenants/tenant-canary`, `tenants/tenant-acme`, …).
- The `path` maps directly to the promotion directory structure in the environment repo.
- `prune: true` is non-negotiable — it is what makes a `git revert` a complete
  rollback rather than a partial one (deleted resources are actually deleted).
- `wait: true` combined with `timeout` makes reconciliation failures observable
  and actionable rather than silently asynchronous.

---

### HelmRelease

**API group:** `helm.toolkit.fluxcd.io/v2`

Renders a Helm chart with per-environment values and reconciles the resulting
resources. It is the per-service delivery unit within an environment.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: estate-scanner
  namespace: data-plane
spec:
  interval: 5m
  chart:
    spec:
      chart: charts/estate-scanner      # path within the GitRepository source
      version: ">=0.0.0-0"              # semver constraint; omit to track HEAD
      sourceRef:
        kind: GitRepository
        name: platform-repo
  values:
    image:
      repository: ghcr.io/acme/data-estate/estate-scanner
      digest: sha256:9f8a3b…            # THE promotion knob — changed by a PR
    replicaCount: 2
  valuesFrom:
    - kind: ConfigMap
      name: estate-scanner-env-values   # per-environment layer (environment-config)
      valuesKey: values.yaml
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
```

**Key field notes:**
- `values.image.digest` — the only field that changes between environments;
  every other field is either a default or comes from the `ConfigMap` overlay.
- `valuesFrom` — the `environment-config` skill owns the `ConfigMap`; the
  `HelmRelease` only references it. This keeps environment-specific values
  (replica counts, resource limits, feature flags) out of the promotion PR and
  in their own governance path.
- `remediation.retries` — required for production environments; Helm upgrades
  that fail will be retried and, on final failure, rolled back automatically
  by Flux before the post-deploy verification job even runs.

---

## Multi-Controller Composition Pattern

The three CRDs form a directed dependency graph:

```
GitRepository (platform-repo)
       │
       ├──► Kustomization (dev-environment)
       │         │
       │         ├──► HelmRelease (estate-scanner) in data-plane namespace
       │         ├──► HelmRelease (compliance-engine) in data-plane namespace
       │         ├──► HelmRelease (document-ingestion) in data-plane namespace
       │         └──► ConfigMap / NetworkPolicy (supporting resources)
       │
       ├──► Kustomization (staging-environment)
       │         └──► (same structure)
       │
       └──► Kustomization (tenant-canary-environment)
                 └──► (same structure)
```

**What this means in practice:**
1. A single `GitRepository` poll fetches the latest commit and makes the tree
   available to all downstream controllers simultaneously.
2. Each `Kustomization` independently reconciles its environment directory — a
   failure in one environment's reconciliation does not block others.
3. Each `HelmRelease` independently renders and applies its chart — a failed
   chart upgrade in one service does not block sibling services.
4. Fleet-wide promotions are therefore safe to batch: staging and production
   tenant environments reconcile in parallel once their respective promotion
   PRs merge.

---

## Environment Repo Directory Structure

The directory tree is the environment inventory. Flux reads it; the structure is not
a convention — it is the actual configuration surface the reconciler consumes.

```
deploy/
└── clusters/
    ├── dev/
    │   ├── kustomization.yaml          ← entry Kustomization CRD
    │   ├── estate-scanner.yaml         ← HelmRelease
    │   ├── compliance-engine.yaml      ← HelmRelease
    │   └── document-ingestion.yaml    ← HelmRelease
    ├── staging/
    │   └── (same pattern)
    └── tenants/
        ├── tenant-canary/
        │   └── (same pattern)
        ├── tenant-acme/
        │   └── (same pattern)
        └── tenant-globex/
            └── (same pattern)
```

Each leaf `kustomization.yaml` contains:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - estate-scanner.yaml
  - compliance-engine.yaml
  - document-ingestion.yaml
```

This is the Kustomize config file (lowercase `k`) consumed by the Flux
`Kustomization` CRD (uppercase `K`) — not itself a CRD, but the build manifest
that tells `kustomize build` which resources to include.

---

## Worked Example: Promoting compliance-engine 1.4.0

**Step 1 — CI produces the artifact**

Merge to `main` triggers the CI pipeline (`ci-pipeline`). CI builds, tests, signs,
and scans the image. Output: `compliance-engine@sha256:4be1a9f3…`, signed via
Cosign, Trivy-clean.

**Step 2 — Auto-commit to dev**

CI's final step commits the new digest to `deploy/clusters/dev/compliance-engine.yaml`:

```yaml
# deploy/clusters/dev/compliance-engine.yaml (after CI commit)
spec:
  values:
    image:
      digest: sha256:4be1a9f3…   # was sha256:7c3d2e1a...
```

Commit message: `chore: promote compliance-engine@sha256:4be1a9f3… to dev`

Flux polls, detects the change, and converges dev within 5 minutes.

**Step 3 — Post-deploy verification on dev**

The GitHub Actions workflow `post-deploy-dev.yml` triggers on the commit:
1. `flux get helmreleases -n data-plane compliance-engine` — waits for Ready.
2. Calls `/readyz` on all pods.
3. Runs smoke-tagged e2e tests.
4. Queries Prometheus burn rate for a 15-minute soak window.

All pass → opens a PR: `chore: promote compliance-engine@sha256:4be1a9f3… to staging`.

**Step 4 — Staging promotion**

Platform-engineer reviews and merges the staging PR. The nightly e2e and load suites
run against staging. A 30-minute SLO soak window passes clean.

**Step 5 — Canary production promotion**

PR opened for `deploy/clusters/tenants/tenant-canary/`. Shafi approves.

Flux converges the canary tenant. In-cluster `canary-deployment` shifts traffic:
10% → 30-min SLO check → 50% → 30-min SLO check → 100%.

**Step 6 — Fleet-wave promotions**

PRs opened for remaining tenant directories, batched. One tenant's burn-rate check
trips during the 50% soak:

- Post-deploy job triggers a rollback:
  ```
  git revert <promotion-commit> -m "SLO burn rate exceeded at 50% canary [ROLLBACK]"
  git push
  ```
- The commit message includes `[ROLLBACK]` — counted by `dora-metrics` CFR instrumentation.
- The GitHub Actions workflow emits the `report-rollback` step, logging the reverted
  environment and digest to the metrics sink.
- Flux converges that tenant back to the previous digest within 5 minutes.
- The other tenants' promotions are unaffected — per-tenant PRs, per-tenant rollback.

---

## Output Format Template

Produced artifacts carry this frontmatter and structure:

```markdown
---
name: cd-pipeline-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# CD Pipeline — [product]

## Reconciler Decision
[Flux vs Argo CD decision table outcome, recorded as ADR reference]
Chosen: Flux / Argo CD — rationale: [from selection table in cd-pipeline skill]

## Environment Repo Layout
deploy/clusters/{dev,staging}/[service-name].yaml
deploy/clusters/tenants/[tenant-id]/[service-name].yaml

## GitRepository
Name: [repo-name]
URL: [git-url]
Interval: 1m
Secret: [deploy-key-secret-name]

## Promotion Flow
| Environment | Trigger | Approval | Soak Window |
|---|---|---|---|
| dev | Auto-commit by CI | None | 15 min |
| staging | Automated PR | Platform-engineer | 30 min |
| tenant-canary | Manual PR | Shafi | Per canary step |
| fleet tenants | Batched PRs | Platform-engineer | Per canary step |

## Rollback Procedure
Command: git revert <promotion-commit>
Tagging: subject line must include [ROLLBACK]
Workflow step: report-rollback must fire and log to dora-metrics sink
Last drill date: [date]
Measured time-to-restore: [minutes]

## Change Failure Rate Baseline
Promotion events this quarter: [n]
Rollback events this quarter: [n]
CFR: [n%] — target ≤ 15%

## Drift Response
Alert route: [Alertmanager route name]
Incident severity: P2
Escalation: Platform-engineer on-call → Shafi if production

## Traceability
NFR IDs: [availability NFR], [RTO NFR]
multi-tenancy-design fleet rules: implemented via per-tenant directory + per-tenant PR
```

---

## Full Quality Criteria Table

| Criterion | Pass | Fail | Notes |
|---|---|---|---|
| Git is the source of truth | Every environment fully described in the repo | State that exists only in a cluster | No exceptions — even "temporary" hand-edits are drift |
| Reconciler applies | In-cluster reconciliation; humans merge PRs | CI or humans running `kubectl apply`/`helm upgrade` | CI's write access ends at registry + environment repo |
| Digest promotion | Environments differ only by values + digest pointer | Rebuild per environment, or tag-based promotion | Rebuild invalidates all prior test provenance |
| CRD structure correct | `Kustomization` top-level; `HelmRelease` per service; `GitRepository` shared | Monolithic manifests; missing `prune: true` | `prune: true` is required for revert completeness |
| Verification gates | Health + smoke + SLO burn block the next stage | "Deployed" declared at apply time | All three gates required — any two is theatre |
| Rollback = revert | `git revert` with `[ROLLBACK]` tag; `report-rollback` step fires | Rollback requiring manual steps; tag absent | Tag absence makes CFR invisible |
| Drift handling | Reverted **and** alerted as an incident | Silent revert, or drift tolerated | Alert is required even when revert succeeds |
| Secrets boundary | Zero credentials in the environment repo | Passwords/keys in values files | One committed credential triggers rotation + incident |
| Fleet waves | Canary tenant → waves, per-tenant revert | Big-bang promotion to all tenants | Per-tenant revert is the blast-radius control |
| CFR tracked | CFR computed and reviewed quarterly | CFR unknown or unmeasured | ≤ 15% target (DORA high performer threshold) |
