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
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, environments, parity, configuration-as-code, values, promotion, tenants]
related: [cd-pipeline, helm-chart, multi-tenancy-design, feature-flag-design, disaster-recovery-plan, gitops-workflow, platform-engineering]
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

## Local Environment — kind and `make local-up`

`kind-local` is not a docker-compose substitute — it is a real, multi-node Kubernetes cluster running inside Docker containers on the developer's laptop. The tool is **kind** (Kubernetes IN Docker). docker-compose environments, locally-installed binaries, and mocks all break parity before CI begins and are not compliant.

`make local-up` is the golden path for local setup. It executes three steps in order:

1. `kind create cluster --name <service>` — boots the kind cluster
2. `helm upgrade --install <service> ./charts/<service> -f values/local-values.yaml` — installs the service's Helm chart with local overrides (reduced sizing, local endpoints)
3. `kind load docker-image <image>:<digest>` — loads the locally-built image directly into the kind cluster without a registry round-trip

A new engineer runs `make local-up` on day one and gets a working Kubernetes environment with the real chart and the real locally-built image — no documentation to read, no platform engineer to ask (Thinnest Viable Platform principle from `platform-engineering`). If `make local-up` requires more than one command or requires reading a setup guide first, the golden path has failed.

CI also runs `kind` for the chart-install gate in `helm-chart`: the same `make local-up` target (or its CI equivalent) that engineers use is the same gate that blocks a merge — one tested path, not two.

---

## Identical Provisioning Process

Environment parity is not only about what runs — it is about *how* environments are built. Dev and staging must be provisioned by **the same automated OpenTofu + Helm process** as production tenant stamps, not merely styled to resemble production. "Mirrors production topology" is not enough if the mirror was assembled by hand.

| Environment | Must be provisioned by | A hand-built environment is |
|---|---|---|
| kind-local | `make local-up` (automated, one command) | A defect — breaks golden path; fails the TVP test |
| dev | CI auto-commit → GitOps reconciler (same OpenTofu + Helm path) | A defect — cannot verify the provisioning process itself |
| staging | PR to env repo → Flux reconciler (same OpenTofu + Helm path) | A defect — staging cannot rehearse production provisioning |
| tenant-* prod | PR per fleet wave → Flux reconciler | A defect — production diverges from what staging proved |

A dev environment built by hand cannot demonstrate that the automated provisioning path works. That is the purpose of dev: the first real-cluster convergence after a merge verifies not just the image but the automated pipeline that will build staging and every production tenant stamp.

---

## Environment-Repo Directory Conventions

The environment repo tree maps 1:1 to clusters and namespaces. The GitOps agent's source is a path in this tree — the tree structure is the environment inventory, not a CI variable or a runtime query:

```
clusters/
  <cluster-name>/
    namespaces/
      <namespace>/
        <service>-helmrelease.yaml    # Flux HelmRelease — per-service chart delivery
        <service>-kustomization.yaml  # Flux Kustomization — raw or overlay manifests
```

Each leaf file is a Flux CRD: a `HelmRelease` for chart-based services (the standard path for this repo) or a `Kustomization` for raw or kustomize-processed manifests. Navigating the filesystem answers "what is deployed where" without querying any cluster or reading any pipeline log.

Per-tenant production stamps follow the same layout:

```
clusters/
  tenant-acme/
    namespaces/
      tenant-acme/
        estate-scanner-helmrelease.yaml
  tenant-globex/
    namespaces/
      tenant-globex/
        estate-scanner-helmrelease.yaml
```

Adding a new tenant is adding a new `clusters/tenant-<id>/` directory and applying a root Kustomization or HelmRelease — not installing or configuring a new GitOps agent. Diffing two tenant directories is the tenant comparison report.

---

## Projected Volume Pattern

Instead of separate `volumeMounts` for the ConfigMap, the Vault-injected secret, and the serviceAccountToken, use a **projected volume** that combines them into one filesystem path. This reduces the number of `volumeMount` entries per pod and the number of RBAC grants required:

```yaml
volumes:
  - name: config
    projected:
      sources:
        - configMap:
            name: estate-scanner-config
        - secret:
            name: estate-scanner-vault-secret   # written by Vault Agent sidecar
        - serviceAccountToken:
            path: token
            expirationSeconds: 3600
            audience: estate-scanner
volumeMounts:
  - name: config
    mountPath: /etc/service
    readOnly: true
```

The application reads `/etc/service/config.yaml`, `/etc/service/db-password`, and `/etc/service/token` from a single mount path. RBAC grants are scoped to the one `ServiceAccount` that the projected `serviceAccountToken` source already identifies — no separate grant per secret-volume source is needed. The Vault Agent sidecar writes its injected credentials into the same projected volume directory.

---

Full worked example (tenant-acme), quality criteria, anti-patterns, and output template: `references/environment-config-reference.md`.
