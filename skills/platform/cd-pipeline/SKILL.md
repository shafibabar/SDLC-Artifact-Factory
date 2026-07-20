---
name: cd-pipeline
description: >
  Teaches the GitOps continuous delivery model — desired state in Git applied by
  automated reconciliation, environment promotion by immutable image digest via
  pull request, post-deploy verification (health, smoke, SLO burn), rollback as
  git revert, drift detection as an incident, and the secrets boundary that keeps
  credentials out of Git. Tool-agnostic model with Flux as the frugal default
  implementation. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, cd, gitops, flux, promotion, rollback, reconciliation, drift]
---

# CD Pipeline

## Purpose

Continuous delivery on this platform is **GitOps**: the desired state of every environment lives in Git, and an in-cluster reconciler continuously makes reality match it. Nobody deploys *to* a cluster; they merge a commit that *describes* the cluster, and the reconciler applies it. This inverts the push model — the cluster pulls its own state — and it buys three properties no push pipeline offers: every change is a reviewable diff, the audit log is `git log`, and rollback is `git revert`.

Manual `kubectl apply` against a live environment is an incident, not a workflow.

---

## The Reconciliation Model (Tool-Agnostic)

Four parts, regardless of tool:

```
┌──────────────┐   merge PR    ┌───────────────────┐
│  CI pipeline │ ────────────► │  Environment repo │  (desired state: Helm values,
│  (digest out)│               │  (Git)            │   digests, manifests per env)
└──────────────┘               └────────┬──────────┘
                                        │ pull & diff (every few minutes)
                               ┌────────▼──────────┐
                               │  Reconciler       │  in-cluster controller
                               │  (Flux / Argo CD) │
                               └────────┬──────────┘
                                        │ apply / correct
                               ┌────────▼──────────┐
                               │  Cluster          │  actual state
                               └───────────────────┘
```

1. **Desired state** — Helm Chart releases, per-environment values, image digests — is plain files in an environment repo (or `deploy/` paths in the monorepo).
2. **The reconciler** runs inside each cluster, pulls the repo, and applies the diff.
3. **Convergence is continuous** — not only on merge. If actual state deviates (someone edited a Deployment by hand), the reconciler reverts it.
4. **Promotion is a commit** — a PR that changes a digest string in an environment's values file.

### Choosing the Reconciler

Recorded as a decision, not a mandate — both are CNCF-graduated, open-source, and fit the frugal posture:

| Concern | Flux | Argo CD | Weight for this product |
|---|---|---|---|
| Footprint | Small set of controllers, low memory | Heavier (API server, UI, Redis) | High — per-tenant clusters multiply every megabyte |
| UI | None (CLI + Git) | Full web UI | Low — Han Solo operator works in Git anyway |
| Helm support | Native `HelmRelease` CRD | Renders charts to manifests | Medium — charts are the delivery unit (`helm-chart`) |
| Multi-cluster fleet | Bootstrap per cluster from one repo | Hub-and-spoke from one control plane | Medium — either handles per-tenant stamps |
| Image automation | Built-in image update controllers | Separate project (Argo CD Image Updater) | Low — promotion is by PR, not automation |

**Default: Flux**, for lightness across a per-tenant fleet. Revisit via ADR if a UI-driven operational need emerges.

### Reconciliation Config Sketch (Flux)

```yaml
# deploy/clusters/dev/estate-scanner.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: estate-scanner
  namespace: data-plane
spec:
  interval: 5m
  chart:
    spec:
      chart: charts/estate-scanner        # one chart per service (helm-chart)
      sourceRef: { kind: GitRepository, name: platform-repo }
  values:
    image:
      repository: ghcr.io/acme/data-estate/estate-scanner
      digest: sha256:9f8a3b…              # THE promotion knob — a PR changes this line
  valuesFrom:
    - kind: ConfigMap
      name: estate-scanner-env-values      # per-environment layer (environment-config)
```

---

## Promotion by Digest

The artifact never changes between environments; only the pointer to it moves. CI publishes a signed digest once (`ci-pipeline`); promotion is a pull request that updates that digest in the next environment's path:

```
deploy/
├── clusters/
│   ├── dev/          ← auto-committed by CI on green main
│   ├── staging/      ← PR, merged after dev soak + nightly suites green
│   └── tenants/
│       ├── tenant-canary/   ← PR, first production wave (internal tenant)
│       ├── tenant-acme/     ← PR, wave 2 (after canary SLO check)
│       └── tenant-globex/   ← PR, wave 2
```

| Environment | Promotion trigger | Approval |
|---|---|---|
| dev | Automated commit from CI on merge to main | None — dev is disposable |
| staging | PR raised automatically; merged when dev post-deploy checks + nightly suites are green | Platform-engineer review |
| production (per tenant) | PR per wave: canary tenant first, then fleet waves | Shafi approves the first production promotion of each release |

Per-tenant production directories implement the fleet-wave model from `multi-tenancy-design`: one designated canary tenant, then waves, with bounded version skew. Rollout *within* a tenant is progressive too — `canary-deployment` (default) or `blue-green-deployment` govern the in-cluster traffic shift.

---

## Post-Deploy Verification

A promotion is not done when the reconciler applies it; it is done when the environment proves it. The verification job (a GitHub Actions workflow triggered on the environment-repo merge) checks, in order:

1. **Reconciled** — `flux get helmreleases` reports Ready, the new digest is what's running.
2. **Health** — every service's `/readyz` (from `health-check-design`) returns ready across all replicas.
3. **Smoke** — the test-strategist's tagged smoke subset of `go-e2e-test` runs against the environment: scan a fixture document, verify the compliance finding lands.
4. **SLO burn** — Prometheus burn-rate queries (`slo-definition`, `alerting-rules-design`) show no fast-burn for a soak window (e.g. 30 min staging, per-wave in production).

Any failure blocks further promotion and, in production, triggers rollback.

---

## Rollback = Git Revert

Because the desired state is a commit, rollback is `git revert <promotion-commit>` — the reconciler applies the previous digest, which is still signed, still scanned, still in the registry. No memory of "what was deployed" is needed; no snowflake restore procedure exists.

Two rules make this always-safe:

- **Schema compatibility** — the backend-engineer's `go-migration` expand → migrate → contract discipline means digest N−1 always runs against digest N's schema within the skew window. A revert never requires a database rollback.
- **Rollback is drilled** — a revert is executed against staging on a schedule (the agent's completion criteria demand a demonstrated rollback). An untested rollback path is a hope, not a capability.

---

## Drift Is an Incident

The reconciler continuously compares desired and actual state. Any divergence — a hand-edited Deployment, a deleted NetworkPolicy, a scaled replica count — is **drift**, and drift is an incident, not a customisation channel:

- The reconciler **reverts** the drift (Flux does this by default on its interval).
- The drift event is **alerted** (Alertmanager route to the incident channel) — reverting silently hides that someone or something bypassed Git.
- The incident answer is never "make the manual change stick"; it is "merge the change, or explain the access that allowed it" (Zero Trust posture — cluster write access is the reconciler's, not humans').

The same rule binds infrastructure: OpenTofu drift detection is `opentofu-module`'s half of this contract.

---

## The Secrets Boundary

**Values files never carry secrets.** The environment repo is the most-read repo in the company; it must contain zero credentials:

- Application secrets (database passwords, API keys) reach pods via the **Vault Agent sidecar** injecting into an in-memory volume — configured by the security-engineer (`secrets-management`); the chart only mounts the pattern.
- The reconciler's own Git credential is a read-only deploy key, per cluster.
- Anything that must transit Git (rare) uses sealed/external-secrets encryption so the repo holds only ciphertext — recorded via ADR if the need arises; the default is that it does not.

A digest, a replica count, a resource limit belong in Git. A password never does.

---

## Worked Example — Promoting compliance-engine 1.4.0

1. Merge to main → CI publishes `compliance-engine@sha256:4be1…`, signed, Trivy-clean.
2. CI auto-commits the digest to `deploy/clusters/dev/`. Flux converges dev in <5 min; post-deploy job: readyz green, smoke green.
3. Nightly e2e/load suites pass → an automated PR updates `deploy/clusters/staging/`. Platform-engineer merges; 30-min SLO soak clean.
4. PR to `deploy/clusters/tenants/tenant-canary/` — Shafi approves. Canary tenant converges; in-cluster Canary Deployment shifts traffic 10% → 50% → 100% gated on burn rate.
5. Wave PRs to the remaining tenant directories, batched. One tenant's burn-rate check trips → that tenant's promotion PR is reverted; the other tenants are untouched — per-tenant rollback exactly as `multi-tenancy-design` promises.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Git is the source of truth | Every environment fully described in the repo | State that exists only in a cluster |
| Reconciler applies | In-cluster reconciliation; humans merge PRs | CI or humans running `kubectl apply`/`helm upgrade` |
| Digest promotion | Environments differ only by values + digest pointer | Rebuild per environment, or tag-based promotion |
| Verification gates | Health + smoke + SLO burn block the next stage | "Deployed" declared at apply time |
| Rollback = revert | Demonstrated revert restores previous digest | Rollback requiring manual steps or tribal memory |
| Drift handling | Reverted **and** alerted as an incident | Silent revert, or drift tolerated |
| Secrets boundary | Zero credentials in the environment repo | Passwords/keys in values files |
| Fleet waves | Canary tenant → waves, per-tenant revert | Big-bang promotion to all tenants |

---

## Anti-Patterns

- **Push-based "GitOps"** — a CI job running `helm upgrade` with cluster-admin credentials is the old model wearing the new name. The cluster pulls; CI's write access ends at the registry and the environment repo.
- **Promotion by rebuilding** — building "the same" code again for staging produces a different, unsigned artifact. Provenance dies at the second build.
- **kubectl as a support tool** — "just this once" hand-edits become the undocumented production state. Read access for humans, write access for the reconciler.
- **Verification theatre** — a `sleep 60 && curl /healthz` after deploy proves the process starts, not that the release works. Health, smoke, *and* SLO burn — all three.
- **Rollback that migrates down** — if reverting a digest requires a down-migration, the expand/contract discipline was violated upstream; escalate to the backend-engineer, don't script around it.
- **Secrets in values "temporarily"** — Git never forgets. One committed credential means rotation, history rewriting, and an incident report. The boundary is absolute.
- **Un-alerted drift correction** — a reconciler quietly fixing drift forever masks a compromised credential or a broken process. Revert *and* page.

---

## Output Format

Produces the environment repo structure and reconciliation config:

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

## Environment Repo Layout
deploy/clusters/{dev,staging}/…
deploy/clusters/tenants/[tenant-id]/…

## Promotion Flow
[Per environment: trigger, approval, verification gates, soak window]

## Rollback Procedure
[git revert flow + last drill date and measured time-to-restore]

## Drift Response
[Alert route, incident severity, escalation]

## Traceability
[NFR IDs (availability, RTO), multi-tenancy-design fleet rules implemented]
```
