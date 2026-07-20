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
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, kubernetes, workload, securitycontext, networkpolicy, probes, linkerd, pdb]
---

# Kubernetes Manifest

## Purpose

This skill defines what a conforming workload *is* on this platform: the standards every manifest must meet, whichever chart rendered it (`helm-chart` owns the templating; this skill owns the rendered truth). The standards implement the Zero Trust workload layer inside each tenant's namespace — because under physical multi-tenancy (`multi-tenancy-design`) every tenant runs the full stack, and a weak default multiplies across the fleet.

A workload that cannot meet a standard is a defect in the service, escalated to its owning engineer — never a manifest exception.

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
| CPU limit | **Omitted by default** | CPU throttling adds latency for no safety win; requests + node sizing bound usage |
| Memory request | Required | Same scheduling contract |
| Memory limit | Required, = request (Guaranteed-leaning) | Memory is incompressible; an unbounded leak evicts neighbours. OOMKill is diagnosable; slow eviction is not |

Every namespace carries a `LimitRange` (defaults) and `ResourceQuota` (tenant sizing tier from `opentofu-module`'s stamp), so an unconfigured workload cannot land unbounded.

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

The images already conform (`dockerfile-patterns`: non-root UID, no runtime FS writes) — the manifest *enforces* what the image *promises*. Services needing scratch space mount an explicit `emptyDir` at a named path; the root filesystem stays read-only. Namespaces are labelled for Pod Security Admission `restricted`, so a non-conforming pod is rejected at admission, not discovered in review.

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
# In the pod spec — replicas spread across nodes (and zones where available):
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway   # DoNotSchedule only where node count guarantees satisfiability
    labelSelector: { matchLabels: { app.kubernetes.io/name: estate-scanner } }
```

Rule of thumb: `minAvailable`/`maxUnavailable` must leave enough capacity to serve the SLO (`slo-definition`) during a rolling node upgrade — a PDB of `maxUnavailable: 1` on a 2-replica service means upgrades proceed one node at a time, which is the point.

---

## Network — Default-Deny, Explicit Allows

Every tenant namespace starts closed; every flow is an explicit, reviewable allow (Zero Trust inside the boundary — the *cross*-tenant boundary is already physical):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
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
    - to: [{ podSelector: { matchLabels: { app.kubernetes.io/name: postgres } } }]      # its DB
      ports: [{ port: 5432 }]
    - to: [{ podSelector: { matchLabels: { app.kubernetes.io/name: redpanda } } }]      # event stream
      ports: [{ port: 9092 }]
    - ports: [{ port: 53, protocol: UDP }]                                              # DNS
    - ports: [{ port: 443 }]                                                            # Google Drive / S3 APIs
```

The allow set *is* the Container Diagram made enforceable — estate-scanner may reach its PostgreSQL, Redpanda, DNS, and the external source APIs it scans; nothing else. A new arrow in the architecture is a new NetworkPolicy rule in a reviewed PR.

---

## Service Mesh, Identity, and Shutdown

**Linkerd injection** — every workload pod carries `linkerd.io/inject: enabled`; the Service Mesh provides automatic mTLS and per-route metrics between services. Probes are exempt from mTLS by design (kubelet is not a mesh member) — health ports work because Linkerd skips inbound proxying for probe paths.

**ServiceAccount per service, never `default`:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: estate-scanner }
automountServiceAccountToken: false   # true only for services that call the K8s API (rare)
```

Per-service identity is what RBAC, Vault Agent auth (`secrets-management`), and audit attribution key on. A pod on the `default` account is anonymous in every one of those systems.

**Graceful shutdown — aligned with `go-service-skeleton`.** The Go server drains for up to 25s after SIGTERM (not-ready first, then `srv.Shutdown`). The manifest must leave room for that ordering:

```yaml
terminationGracePeriodSeconds: 30    # > the server's 25s drain deadline — SIGKILL never lands mid-drain
containers:
  - lifecycle:
      preStop:
        sleep: { seconds: 3 }        # endpoint-removal propagation before SIGTERM arrives
```

The `preStop` sleep covers the gap between "pod marked terminating" and "every kube-proxy/mesh has stopped routing to it" — SIGTERM arrives *after* traffic has moved, the server drains what's in flight, and deploys drop zero requests.

---

## HPA Guidance

Autoscaling is opt-in per service, off by default (`helm-chart`'s `autoscaling.enabled`):

| Service shape | Scale on | Notes |
|---|---|---|
| Request-serving (compliance-engine API) | CPU utilisation ~70% of request | Simple, robust; requires honest CPU requests |
| Queue-consuming (entity-extractor) | Consumer lag via Prometheus Adapter (`prometheus-metrics-design`) | CPU is the wrong signal for backlog; lag is |
| Scheduled/bursty (estate-scanner crawls) | Usually none — sized for the burst, or run as Jobs | HPA reaction lags a crawl's ramp |

Bounds always set (`minReplicas` ≥ PDB floor, sane `maxReplicas` within the tenant's ResourceQuota); scale-down stabilisation ≥ 5 min to prevent flapping. An HPA without a matching PDB can scale below safe disruption capacity — they are reviewed together.

---

## Worked Example — estate-scanner Rendered Workload

What the estate-scanner chart must render to in `tenant-acme`'s namespace (extract):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: estate-scanner
  labels: { app.kubernetes.io/name: estate-scanner, app.kubernetes.io/part-of: data-estate-platform, tenant: acme }
spec:
  replicas: 2
  template:
    metadata:
      annotations: { linkerd.io/inject: enabled }
    spec:
      serviceAccountName: estate-scanner
      terminationGracePeriodSeconds: 30
      securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
      topologySpreadConstraints: [ { maxSkew: 1, topologyKey: kubernetes.io/hostname,
        whenUnsatisfiable: ScheduleAnyway, labelSelector: { matchLabels: { app.kubernetes.io/name: estate-scanner } } } ]
      containers:
        - name: estate-scanner
          image: ghcr.io/acme/data-estate/estate-scanner@sha256:9f8a3b…   # digest, per ci-pipeline
          ports: [{ name: http, containerPort: 8080 }]
          securityContext: { allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: { drop: ["ALL"] } }
          resources: { requests: { cpu: 100m, memory: 128Mi }, limits: { memory: 256Mi } }
          startupProbe:   { httpGet: { path: /startupz, port: http }, failureThreshold: 30, periodSeconds: 5 }
          livenessProbe:  { httpGet: { path: /healthz,  port: http }, periodSeconds: 10, failureThreshold: 6 }
          readinessProbe: { httpGet: { path: /readyz,   port: http }, periodSeconds: 5,  failureThreshold: 2 }
          lifecycle: { preStop: { sleep: { seconds: 3 } } }
          envFrom: [{ configMapRef: { name: estate-scanner-env } }]       # environment-config; no secrets here
```

Alongside it: the ServiceAccount, PDB, and NetworkPolicy shown above, and the Vault Agent sidecar annotation set per the security-engineer's `secrets-management` pattern. The identical rendered shape lands in every tenant namespace — only values differ.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Probe semantics | Three endpoints → three probes, correct semantics | Liveness on `/readyz`, or one endpoint for both |
| Resources honest | Requests from load data; memory limited; CPU unthrottled by default | Guessed requests, CPU limits by reflex, unlimited memory |
| SecurityContext | Full restricted block; PSA `restricted` on namespace | Any workload runnable as root or writable-root |
| Disruption-safe | PDB + topology spread on every multi-replica service | Replicas co-scheduled or drainable together |
| Network closed | Default-deny + explicit allows matching the Container Diagram | Open namespace, or allows nobody can justify |
| Identity | ServiceAccount per service; token automount off by default | Pods on `default`, tokens mounted unused |
| Mesh | Linkerd injection on all workloads (mTLS) | Un-meshed pods speaking plaintext in-namespace |
| Shutdown aligned | grace 30s > drain 25s; preStop covers routing lag | SIGKILL mid-drain; connection errors on deploy |
| HPA bounded | Right signal per shape; bounds; PDB-consistent | CPU-scaling a queue consumer; unbounded max |

---

## Anti-Patterns

- **Liveness as a dependency check** — the restart storm: database blips, every replica's liveness fails, the orchestrator kills a fleet that was merely waiting. Liveness stays trivial; `health-check-design` is explicit about this.
- **CPU limits everywhere "for safety"** — throttling adds tail latency that shows up as SLO burn with no corresponding protection; requests already reserve capacity.
- **`terminationGracePeriodSeconds` ≤ the drain deadline** — a 20s grace against a 25s drain means every deploy SIGKILLs mid-flight requests; the two numbers are one contract with `go-service-skeleton`.
- **NetworkPolicy as documentation** — policies written but no default-deny means every unlisted flow still works; the allowlist is fiction until the deny exists.
- **The shared `default` ServiceAccount** — every pod becomes the same principal; Vault auth, RBAC, and audit all collapse into "someone in the namespace."
- **Skipping the mesh for "simple" services** — one un-meshed workload reintroduces plaintext and breaks the uniform mTLS story sold in the compliance narrative (Encryption in Transit).
- **HPA fighting the rollout** — autoscaler and Canary Deployment (`canary-deployment`) both steering replicas without coordination causes oscillation; canary analysis windows must account for HPA stabilisation.
- **Secrets via env in the manifest** — `env: value:` with a credential puts it in Git and `kubectl describe`. The Vault Agent in-memory volume is the only secrets path.

---

## Output Format

Produces the workload standards record and per-service rendered-manifest audits:

```markdown
---
name: kubernetes-manifest-[service]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Workload Manifest — [service]

## Rendered Objects
Deployment · Service · ServiceAccount · PodDisruptionBudget · NetworkPolicy · (HPA)

## Probe Wiring
[Endpoint → probe → thresholds → rationale]

## Resource Sizing
[Requests/limits with the load-test evidence (go-load-test run) behind them]

## Network Allows
[Flow table: from → to → port → Container Diagram arrow it implements]

## Shutdown Contract
[Server drain deadline, grace period, preStop — aligned values]

## Traceability
[Container Diagram element; NFR IDs (availability, security); SLO reference]
```
