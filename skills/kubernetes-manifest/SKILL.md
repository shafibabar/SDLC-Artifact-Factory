---
name: kubernetes-manifest
description: >
  Teaches the Kubernetes workload standards every rendered manifest must meet —
  Deployments with probes wired to the health-check-design endpoints, the
  resource requests/limits policy, a hardened securityContext, PodDisruptionBudget,
  topology spread, default-deny NetworkPolicy with explicit allows, Linkerd
  Service Mesh injection, a ServiceAccount per service, HPA guidance, and
  graceful shutdown aligned with the Go server's drain ordering. Used by the
  platform-engineer during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, kubernetes, workload, securitycontext, networkpolicy, probes, linkerd, pdb, init-container, argo-rollouts]
---

# Kubernetes Manifest

## Purpose

This skill defines what a conforming workload *is* on this platform: the standards every manifest must meet, whichever chart rendered it (`helm-chart` owns the templating; this skill owns the rendered truth). The standards implement the Zero Trust workload layer inside each tenant's namespace — because under physical multi-tenancy (`multi-tenancy-design`) every tenant runs the full stack, and a weak default multiplies across the fleet.

A workload that cannot meet a standard is a defect in the service, escalated to its owning engineer — never a manifest exception.

---

## Workload Type Reference

The *workload type decision* — Deployment vs StatefulSet vs DaemonSet vs Job vs CronJob vs Argo Rollout — is owned by **`kubernetes-workload-patterns`**. Consult that skill first; return here for the manifest standards that apply to whichever type was selected. Every standard in this skill applies regardless of workload controller.

---

## Probes — Wired to `health-check-design`

The backend-engineer builds three endpoints with precise semantics; the manifest wires each to the probe that matches its question — and never cross-wires them:

| Endpoint | Probe | Config rationale |
|---|---|---|
| `/healthz` (dependency-free) | `livenessProbe` | Generous thresholds — restarts are for wedged processes only |
| `/readyz` (deps + draining state) | `readinessProbe` | Short period — traffic routing must react fast |
| `/startupz` | `startupProbe` | High `failureThreshold × periodSeconds` covering worst-case start (migrations, pool warmup); suppresses liveness until done |

```yaml
livenessProbe:
  httpGet: { path: /healthz, port: http }
  periodSeconds: 10
  failureThreshold: 6          # a full minute of true wedge before restart
readinessProbe:
  httpGet: { path: /readyz, port: http }
  periodSeconds: 5
  failureThreshold: 2          # out of rotation within ~10s of trouble
startupProbe:
  httpGet: { path: /startupz, port: http }
  periodSeconds: 5
  failureThreshold: 30         # up to 150s to start before anyone panics
```

Readiness failure removes from the Service endpoints; it never restarts. Wiring `/readyz` to liveness turns every database blip into a fleet restart storm — the exact outage `health-check-design` exists to prevent.

---

## Resources — Requests Are a Promise, Limits Are a Policy

| Resource | Policy | Why |
|---|---|---|
| CPU request | Required; sized from load-test data (`go-load-test`), not guesses | Scheduler packs on requests; lies cause noisy-neighbour contention |
| CPU limit | **Omitted by default for latency-sensitive services** | CPU throttling is **silent** — the container is slowed, not killed; the result is latency jitter that presents as an application bug, not a resource event |
| Memory request | Required | Same scheduling contract |
| Memory limit | Required; set within 20% of observed peak | Memory OOM is **observable** — an immediate, recoverable kill signalled as `OOMKilled`; tight limits surface leaks before they evict neighbours |

**CPU vs memory asymmetry:** CPU throttling is silent — it shows as p99 latency degradation with no error rate signal and no log entry. Memory OOMKill is immediate and observable in `kubectl describe pod`. Calibrate memory limits from observed peak under load; omit CPU limits for latency-sensitive services. Every namespace carries a `LimitRange` and `ResourceQuota` from the tenant stamp (`opentofu-module`), bounding unconfigured workloads.

---

## SecurityContext — The Non-Negotiable Block

Rendered unconditionally on every workload (`helm-chart` guarantees presence; this is the required content):

```yaml
securityContext:                    # pod level
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }
containers:
  - securityContext:                # container level
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: ["ALL"] }
```

Images conform (`dockerfile-patterns`); the manifest *enforces* what the image *promises*. Services needing scratch space mount an explicit `emptyDir`; the root filesystem stays read-only. Namespaces carry PSA `restricted` — non-conforming pods are rejected at admission.

---

## Init Container Pattern

Init containers run to completion before any app container starts. Use one when per-pod setup must complete before the main workload and cannot run concurrently with it.

**Use when:** schema migration (`go-migration` `migrate up`) must complete before the API container serves traffic; a Vault secret must be pulled into a shared `emptyDir` before startup; a dependency health wait must pass. **Do not use when** the work runs concurrently with or outlasts the app container — use a sidecar.

**Kubernetes 1.29+ native sidecar:** `restartPolicy: Always` on an `initContainers[]` entry makes the kubelet treat it as a native sidecar — starts before app containers, stays running, restarts on crash. Supersedes the pre-1.29 long-running-init-container hack. Init containers must meet the same `restricted` securityContext requirements as app containers.

Full YAML (migration init container, native sidecar OTel Collector, and Vault secret pull): `references/manifest-reference.md`.

---

## Availability — PDB and Topology Spread

Replicas only help if they don't disrupt together:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: estate-scanner }
spec:
  maxUnavailable: 1                # node drains/upgrades take one replica at a time
  selector: { matchLabels: { app.kubernetes.io/name: estate-scanner } }
---
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway   # DoNotSchedule only where node count guarantees satisfiability
    labelSelector: { matchLabels: { app.kubernetes.io/name: estate-scanner } }
```

`minAvailable`/`maxUnavailable` must leave enough capacity for the SLO (`slo-definition`) during a rolling node upgrade.

---

## Network — Default-Deny, Explicit Allows

Every tenant namespace starts closed; every flow is an explicit, reviewable allow (Zero Trust inside the boundary — the *cross*-tenant boundary is already physical):

```yaml
# default-deny — applied to every namespace:
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
---
# per-service allow — mirrors the Container Diagram:
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: estate-scanner }
spec:
  podSelector: { matchLabels: { app.kubernetes.io/name: estate-scanner } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app.kubernetes.io/name: ingress-gateway } } }]
      ports: [{ port: 8080 }]
  egress:
    - to: [{ podSelector: { matchLabels: { app.kubernetes.io/name: postgres } } }]
      ports: [{ port: 5432 }]
    - to: [{ podSelector: { matchLabels: { app.kubernetes.io/name: redpanda } } }]
      ports: [{ port: 9092 }]
    - ports: [{ port: 53, protocol: UDP }]   # DNS
    - ports: [{ port: 443 }]                 # external APIs
```

A new architecture arrow is a new NetworkPolicy rule in a reviewed PR.

---

## Service Mesh, Identity, and Shutdown

**Linkerd injection** — every pod carries `linkerd.io/inject: enabled`; automatic mTLS and per-route metrics. Probes exempt from mTLS by design.

**ServiceAccount per service, never `default`:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: estate-scanner }
automountServiceAccountToken: false   # true only for services that call the K8s API (rare)
```

Per-service identity is what RBAC, Vault Agent auth (`secrets-management`), and audit attribution key on.

**`terminationGracePeriodSeconds` rule:** set to the app's drain timeout **plus 5 seconds minimum**. A shorter grace period causes Kubernetes to SIGKILL before the drain completes, dropping in-flight requests with no log entry. The `preStop` hook fires before SIGTERM, covering the kube-proxy and mesh routing-propagation gap:

```yaml
terminationGracePeriodSeconds: 30    # Go drain deadline = 25s → 25 + 5 = 30 minimum
containers:
  - lifecycle:
      preStop:
        sleep: { seconds: 3 }        # waits for routing layer before SIGTERM arrives
```

---

## Argo Rollout — Progressive Delivery Workloads

Services using canary or blue-green progressive delivery use `Rollout` (from `argo-rollouts`) **instead of** `Deployment`. The `Rollout` spec embeds the delivery strategy — canary steps with traffic weights and pause conditions, or blue-green with pre/post-promotion analysis runs — making promotion criteria versioned and reviewable in Git, not scripted in a pipeline step.

`helm-chart` must branch on `workloadType: rollout` vs `workloadType: deployment`. All other standards — probes, resources, securityContext, PDB, NetworkPolicy, ServiceAccount, Linkerd injection — apply identically to a `Rollout` pod spec. `AnalysisTemplate` CRDs are specified by `canary-deployment` or `blue-green-deployment`.

Full `Rollout` spec with canary steps, `AnalysisTemplate` references, and blue-green promotion hooks: `references/manifest-reference.md`.

---

## HPA Guidance

Autoscaling is opt-in per service, off by default (`helm-chart`'s `autoscaling.enabled`):

| Service shape | Scale on | Notes |
|---|---|---|
| Request-serving (compliance-engine API) | CPU utilisation ~70% of request | Simple, robust; requires honest CPU requests |
| Queue-consuming (entity-extractor) | Consumer lag via Prometheus Adapter (`prometheus-metrics-design`) | CPU is the wrong signal for backlog; lag is |
| Scheduled/bursty (estate-scanner crawls) | Usually none — sized for the burst, or run as Jobs | HPA reaction lags a crawl's ramp |

Bounds always set (`minReplicas` ≥ PDB floor, sane `maxReplicas` within tenant's ResourceQuota); scale-down stabilisation ≥ 5 min to prevent flapping. An HPA without a matching PDB can scale below safe disruption capacity — they are reviewed together.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Workload type declared | `kubernetes-workload-patterns` consulted; type explicit in chart values | Default Deployment assumed without review |
| Probe semantics | Three endpoints → three probes, correct semantics | Liveness on `/readyz`, or one endpoint for both |
| Resources honest | Requests from load data; memory within 20% of peak; CPU unthrottled for latency-sensitive services | Guessed requests, CPU limits by reflex, unlimited memory |
| Init container correct | One-time pre-start work in init container; sidecars for concurrent/long-running work | Schema migration in main entrypoint |
| SecurityContext | Full restricted block; PSA `restricted` on namespace | Any workload runnable as root or writable-root |
| Disruption-safe | PDB + topology spread on every multi-replica service | Replicas co-scheduled or drainable together |
| Network closed | Default-deny + explicit allows matching the Container Diagram | Open namespace, or allows nobody can justify |
| Identity | ServiceAccount per service; token automount off by default | Pods on `default`, tokens mounted unused |
| Mesh | Linkerd injection on all workloads (mTLS) | Un-meshed pods speaking plaintext in-namespace |
| Shutdown aligned | `terminationGracePeriodSeconds` ≥ drain deadline + 5s; preStop covers routing lag | SIGKILL mid-drain; connection errors on deploy |
| Progressive delivery | Services with canary/blue-green use `Rollout` not `Deployment` | Strategy scripted in pipeline, not declared in manifest |
| HPA bounded | Right signal per shape; bounds; PDB-consistent | CPU-scaling a queue consumer; unbounded max |

---

## Anti-Patterns

- **Liveness as a dependency check** — database blips fail liveness across the fleet, the orchestrator kills a healthy fleet that was merely waiting. Liveness stays trivial.
- **CPU limits everywhere "for safety"** — silent throttling burns the SLO as latency degradation with no protection benefit; requests already reserve capacity.
- **`terminationGracePeriodSeconds` ≤ the drain deadline** — a 20s grace against a 25s drain SIGKILLs mid-flight requests; the two numbers are one contract with `go-service-skeleton`.
- **Long-running work in an init container** — a non-terminating init container blocks all app containers indefinitely; long-running enhancers belong in a sidecar.
- **NetworkPolicy without default-deny** — policies written but no deny means every unlisted flow still works; the allowlist is fiction until the deny exists.
- **Shared `default` ServiceAccount** — every pod becomes the same principal; Vault auth, RBAC, and audit collapse into "someone in the namespace."
- **Skipping the mesh for "simple" services** — one un-meshed workload reintroduces plaintext and breaks the uniform mTLS compliance narrative.
- **`Deployment` for a canary service** — the strategy is scripted in the pipeline, not declared in Git; delivery behaviour is invisible to GitOps reconciliation.
- **HPA fighting the rollout** — autoscaler and canary analysis both steering replicas causes oscillation; analysis windows must account for HPA stabilisation.
- **Secrets via `env: value:`** — puts credentials in Git and `kubectl describe`; the Vault Agent in-memory volume is the only secrets path.

---

## References

Full worked examples (Deployment, Rollout, init container, native sidecar), `terminationGracePeriodSeconds` calculation guide, and Output Format template:

`references/manifest-reference.md`
