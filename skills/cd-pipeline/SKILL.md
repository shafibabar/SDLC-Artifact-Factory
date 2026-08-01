---
name: cd-pipeline
description: >
  Teaches the GitOps continuous delivery model — desired state in Git applied by
  automated reconciliation, environment promotion by immutable image digest via
  pull request, post-deploy verification (health, smoke, SLO burn), rollback as
  git revert, drift detection as an incident, and the secrets boundary that keeps
  credentials out of Git. Tool-agnostic model with Flux as the frugal default
  implementation. Used by the platform-engineer during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, cd, gitops, flux, promotion, rollback, reconciliation, drift, dora, cfr]
produces: cd-pipeline-config
domain: platform
status: stable
---

# CD Pipeline

## Purpose

Continuous delivery on this platform is **GitOps**: the desired state of every environment lives in Git, and an in-cluster reconciler continuously makes reality match it. Nobody deploys *to* a cluster; they merge a commit that *describes* the cluster, and the reconciler applies it. This inverts the push model — the cluster pulls its own state — and buys three properties no push pipeline offers: every change is a reviewable diff, the audit log is `git log`, and rollback is `git revert`.

Manual `kubectl apply` against a live environment is an incident, not a workflow.

---

## Continuous Delivery vs. Continuous Deployment

This pipeline implements **Continuous Delivery**, not Continuous Deployment — the distinction must be named explicitly:

| Model | What it means |
|---|---|
| **Continuous Delivery** | Every change that passes the full pipeline is *proven releasable*. A human decides when to promote to production. |
| **Continuous Deployment** | Every change that clears all pipeline stages ships to production automatically — the human gate is removed entirely. |

This repo implements **Continuous Delivery**. Shafi approves the first production promotion of each release (the canary-tenant PR requires explicit approval); subsequent fleet-wave PRs require platform-engineer review. The pipeline proves releasability; the human decides timing. Adopting Continuous Deployment requires a deliberate ADR — it is not the default.

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

1. **Desired state** — Helm Chart releases, per-environment values, image digests — is plain files in an environment repo.
2. **The reconciler** runs inside each cluster, pulls the repo, and applies the diff.
3. **Convergence is continuous** — not only on merge. If actual state deviates, the reconciler reverts it.
4. **Promotion is a commit** — a PR that changes a digest string in an environment's values file.

### Choosing the Reconciler

| Concern | Flux | Argo CD | Weight for this product |
|---|---|---|---|
| Footprint | Small set of controllers, low memory | Heavier (API server, UI, Redis) | High — per-tenant clusters multiply every megabyte |
| UI | None (CLI + Git) | Full web UI | Low — Han Solo operator works in Git anyway |
| Helm support | Native `HelmRelease` CRD | Renders charts to manifests | Medium — charts are the delivery unit (`helm-chart`) |
| Multi-cluster fleet | Bootstrap per cluster from one repo | Hub-and-spoke from one control plane | Medium — either handles per-tenant stamps |

**Default: Flux**, for lightness across a per-tenant fleet. Revisit via ADR if a UI-driven operational need emerges.

For Flux YAML configuration sketches, multi-controller wiring examples, and a full worked promotion, see `references/flux-crd-composition.md`.

---

## Flux CRD Composition Model

Flux decomposes reconciliation into three explicit CRDs, each with a distinct role:

| CRD | API Group | Role |
|---|---|---|
| `GitRepository` | `source.toolkit.fluxcd.io` | Polls a Git repo on an interval, fetches the commit, and exposes the tree as an artifact that other controllers consume. One per source repo per cluster. |
| `Kustomization` | `kustomize.toolkit.fluxcd.io` | Applies a Kustomize-processed directory from a `GitRepository` source. Used for raw manifests, namespace configuration, and top-level environment entry points. |
| `HelmRelease` | `helm.toolkit.fluxcd.io` | Renders and reconciles a Helm chart from a `HelmRepository` or `GitRepository` source with per-environment values. One per service per environment. |

**How they compose in the environment repo:**

- The environment repo's top-level entry point for each environment directory (`deploy/clusters/dev/`, `deploy/clusters/staging/`, `deploy/clusters/tenants/<id>/`) is a **`Kustomization`** CRD — the single reconciliation root per environment.
- Each environment-level `Kustomization` applies a directory whose contents include one `HelmRelease` per service plus supporting `ConfigMap` and `NetworkPolicy` resources.
- Each service `HelmRelease` references the CI-published digest in its `values.image.digest` field and per-environment configuration from a `ConfigMap` (the `environment-config` layer).
- A single `GitRepository` CRD points at the platform repo and is shared by all `Kustomization` and `HelmRelease` resources in that cluster.

Full CRD field reference, annotated YAML, and multi-controller wiring: `references/flux-crd-composition.md`.

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

Per-tenant directories implement the fleet-wave model from `multi-tenancy-design`.

---

## Post-Deploy Verification

The verification job (triggered on each promotion merge) checks, in order:

1. **Reconciled** — `flux get helmreleases` reports Ready; the new digest is what is running.
2. **Health** — every service's `/readyz` (`health-check-design`) returns ready across all replicas.
3. **Smoke** — the smoke-tagged subset of `go-e2e-test` runs against the environment.
4. **SLO burn** — Prometheus burn-rate queries (`slo-definition`, `alerting-rules-design`) show no fast-burn for a soak window (30 min staging; per-wave in production).

Any failure blocks further promotion and, in production, triggers rollback.

---

## Rollback = Git Revert

Because the desired state is a commit, rollback is `git revert <promotion-commit>` — the reconciler applies the previous digest, still signed, still scanned. No tribal memory required.

Two rules make this always-safe:

- **Schema compatibility** — `go-migration` expand/contract means digest N−1 runs against digest N's schema. A revert never requires a database rollback.
- **Rollback is drilled** — a revert is executed against staging on a schedule. An untested rollback path is a hope, not a capability.

---

## Change Failure Rate Tracking

Every rollback is a data point for DORA's **Change Failure Rate** (CFR):

```
CFR = rollback events in window / total promotion events in window
```

To make rollbacks machine-countable, two tagging conventions are required:

- Every `git revert` of a promotion commit **must include `[ROLLBACK]`** in the commit message subject line, e.g.:
  `Revert "chore: promote compliance-engine@sha256:4be1… to tenant-acme" [ROLLBACK]`
- The GitHub Actions post-deploy verification workflow **must include a named step `report-rollback`** that records the reverted environment and digest to the `dora-metrics` instrumentation sink when a revert is triggered.

The `dora-metrics` instrumentation (`metrics-instrumentation-plan`) queries Git commit history for `[ROLLBACK]` tags and promotion workflow runs for `report-rollback` steps to compute CFR over rolling windows.

**DORA benchmark**: High performers sustain CFR ≤ 15% (Accelerate cluster analysis). A CFR above 15% sustained over a two-week window is a delivery performance incident requiring root-cause investigation before the next promotion cycle — not routine variance to monitor passively.

---

## Drift Is an Incident

The reconciler continuously compares desired and actual state. Any divergence — a hand-edited Deployment, a deleted NetworkPolicy, a scaled replica count — is **drift**, and drift is an incident:

- The reconciler **reverts** the drift (Flux default on its reconciliation interval).
- The drift event is **alerted** (Alertmanager route to the incident channel) — reverting silently hides that something bypassed Git.
- The incident answer is "merge the change, or explain the access that allowed it" — never "make the manual change stick" (Zero Trust posture).
- OpenTofu drift detection is `opentofu-module`'s half of this contract.

---

## The Secrets Boundary

**Values files never carry secrets.** The environment repo must contain zero credentials:

- Application secrets reach pods via **Vault Agent sidecar** injection into an in-memory volume — configured by the security-engineer (`secrets-management`); the chart only mounts the pattern.
- The reconciler's own Git credential is a read-only deploy key, per cluster.
- Anything that must transit Git uses SOPS encryption (Flux's kustomize-controller has native SOPS + age/KMS support) — recorded via ADR if the need arises; the default is that it does not.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Git is the source of truth | Every environment fully described in the repo | State that exists only in a cluster |
| Reconciler applies | In-cluster reconciliation; humans merge PRs | CI or humans running `kubectl apply`/`helm upgrade` |
| Digest promotion | Environments differ only by values + digest pointer | Rebuild per environment, or tag-based promotion |
| Verification gates | Health + smoke + SLO burn block the next stage | "Deployed" declared at apply time |
| Rollback = revert | Demonstrated revert restores previous digest | Rollback requiring manual steps or tribal memory |
| CFR instrumented | `[ROLLBACK]` tags on revert commits; `report-rollback` step present | Rollbacks uncounted; CFR unknown |
| Drift handling | Reverted **and** alerted as an incident | Silent revert, or drift tolerated |
| Secrets boundary | Zero credentials in the environment repo | Passwords/keys in values files |
| Fleet waves | Canary tenant → waves, per-tenant revert | Big-bang promotion to all tenants |

---

## Anti-Patterns

- **Push-based "GitOps"** — a CI job running `helm upgrade` with cluster-admin credentials is the old model in new clothes. The cluster pulls; CI's write access ends at the registry and the environment repo.
- **Promotion by rebuilding** — building "the same" code for staging produces a different, unsigned artifact. Provenance dies at the second build.
- **kubectl as a support tool** — "just this once" hand-edits become undocumented production state. Read access for humans, write access for the reconciler.
- **Verification theatre** — a `sleep 60 && curl /healthz` proves the process starts, not that the release works. Health, smoke, *and* SLO burn — all three.
- **Rollback not tagged** — a revert without `[ROLLBACK]` in the message is invisible to CFR instrumentation; the metric silently under-counts.
- **Secrets in values "temporarily"** — Git never forgets. One committed credential means rotation, history rewriting, and an incident report. The boundary is absolute.
- **Un-alerted drift correction** — a reconciler quietly fixing drift forever masks a compromised credential or a broken process. Revert *and* page.
