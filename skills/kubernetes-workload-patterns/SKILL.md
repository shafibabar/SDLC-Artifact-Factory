---
name: kubernetes-workload-patterns
description: >
  Teaches which Kubernetes workload controller type and pod composition pattern a service requires — Deployment vs StatefulSet vs DaemonSet vs Job/CronJob vs Argo Rollout vs KEDA-scaled — with explicit decision criteria for each, plus the structural composition patterns (Init Container, Sidecar, Adapter, Ambassador) and when multi-container pods are appropriate. The decision input to helm-chart and kubernetes-manifest. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","kubernetes","workload","deployment","statefulset","daemonset","job","cronjob","operator","keda","sidecar","init-container"]
---

# Kubernetes Workload Patterns

## Purpose

This skill answers two questions the `helm-chart` and `kubernetes-manifest` skills presuppose are already resolved:

1. **Which controller type** should own this service?
2. **Which pod composition pattern(s)** apply inside that controller's pod spec?

Both decisions are made *before* templating begins. Getting them wrong creates architectural debt that compounds across the fleet: a Deployment standing in for a DaemonSet will never guarantee one-replica-per-node; a StatefulSet used where a Deployment suffices adds unnecessary operational complexity.

---

## Controller Type Decision

| Controller | Use when | Do NOT use when |
|---|---|---|
| **Deployment** | Service is stateless — any replica can handle any request; the default choice | The service needs stable per-pod identity or persistent-per-instance storage |
| **StatefulSet** | Service needs stable network identity (predictable pod names), stable persistent storage per pod, or ordered startup/shutdown (databases, Redpanda brokers, Zookeeper) | The service has no identity-stable storage and multiple identical replicas are fine |
| **DaemonSet** | Infrastructure agent that must run on every node (or every selected node): Fluent Bit log forwarder, OTel Collector node-level collector, node exporter, Linkerd CNI plugin | A Deployment with a high replica count — a Deployment never guarantees one replica per node |
| **Job** | One-time, run-to-completion work with a defined end state: database schema migration, one-off batch report, ad-hoc data transform | Long-running services; work that recurs on a schedule |
| **CronJob** | Scheduled, run-to-completion work: nightly compliance report, scheduled cache warming, periodic data cleanup | Any long-running service; one-time work that should not repeat |
| **Argo Rollout** | Service requires canary or blue-green progressive delivery with automated analysis (replaces Deployment for those services) | Simple rolling updates are sufficient — a standard Deployment rollout strategy is adequate |
| **KEDA ScaledObject** | Service should scale to zero when idle and scale proportionally to an external metric: Redpanda consumer group lag, queue depth, HTTP request rate | CPU/memory HPA is sufficient — a backlog-driven consumer whose busyness is invisible to CPU metrics |

**Platform stack assignments (these do not require re-evaluation):**
- `estate-scanner`, `compliance-engine`, `entity-extractor` → **Deployment** (stateless request handlers)
- Redpanda brokers, Zookeeper → **StatefulSet** (managed by an Operator — do not author raw manifests)
- Fluent Bit, OTel Collector (node-level) → **DaemonSet**
- Schema migrations → **Job** (run once, pre-deployment, via Init Container or Helm pre-install hook)
- `go-event-consumer` with Redpanda consumer lag → **KEDA ScaledObject** over a Deployment

Full decision table with anti-patterns: `references/controller-decision-table.md`

---

## Composition Pattern Decision

These patterns govern what goes *inside* a pod spec, regardless of the controller above.

### Init Container

**Use when:** Work must complete before the main container starts and cannot run concurrently.
- Vault secret retrieval into a shared `emptyDir` volume
- Database schema migration (`golang-migrate` run) before the service starts
- Health-wait loop for a dependency (Redpanda, Postgres) that must be ready before the service connects
- Cache pre-population from a known source

**Do NOT use for:** Long-running companions (use Sidecar), work that can happen concurrently with startup (use a separate Job or background goroutine), or anything that belongs in the main container's `CMD`.

### Sidecar

**Use when:** A second container enhances the main container's I/O capabilities without requiring the main container to be modified — and the two share a lifecycle.
- Linkerd proxy — mTLS, per-route metrics (auto-injected; no manual spec needed)
- Fluent Bit log forwarder (per-pod variant) reading the app's stdout via shared log volume
- OTel Collector sidecar — app exports to `localhost:4317` (same pod network namespace, no TLS needed)

**Kubernetes 1.29+ native sidecar:** Declare the sidecar in `initContainers` with `restartPolicy: Always`. Kubernetes treats this as a native sidecar: it starts before app containers, stays running while they run, and does not block pod readiness on its own readiness check. This supersedes the long-running-initContainer hack from Kubernetes <1.29.

**OTel Collector — Sidecar vs DaemonSet criterion:**
- **Sidecar:** per-pod cardinality matters (separate traces/metrics per pod), or the pod lifecycle must be independent of node-level collection
- **DaemonSet:** node-level resource efficiency matters; all pods on a node fan out to one collector process

### Adapter

**Use when:** The main container produces output in a non-standard format and the platform's collection pipeline expects a standard format — the sidecar translates without requiring changes to the main container (e.g., legacy log format → structured JSON for the log aggregator).

### Ambassador

**Use when:** The main container makes outbound calls to an external service that cannot be instrumented directly — the sidecar proxy handles retries, circuit breaking, and protocol translation on the main container's behalf (e.g., a service mesh bypass for a third-party binary that cannot accept sidecar injection).

### Multi-Container Pod Decision Criterion

Place two containers in the same pod **only if both conditions are true:**
1. They share a lifecycle — one cannot usefully run without the other.
2. They cannot operate independently — separate pods on separate Services would break their function.

"Logically related" is not sufficient. Loose coupling via Kubernetes Service DNS belongs in separate pods. When in doubt: separate pods.

---

## Self-Awareness — Downward API

When a container needs its own pod name, namespace, node name, resource limits, or labels at runtime (e.g., to tag every log line or trace with its pod identity), use the **Downward API** — project these facts as environment variables or a volume file. The container reads them without calling the Kubernetes API, before its entrypoint runs.

```yaml
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

---

## Relationship to Other Skills

- `kubernetes-manifest` — owns the rendered standards (probes, resources, securityContext, NetworkPolicy, shutdown alignment) for whichever controller type this skill selects.
- `helm-chart` — the chart template must branch on the controller type this skill decides; its `values.yaml` `workloadType` field is the selector.
- `keda-scaling-config` reference — concrete `ScaledObject` YAML for this platform's services.

---

## References

- `references/controller-decision-table.md` — full decision table with platform-specific examples and anti-patterns
- `references/composition-patterns-catalogue.md` — Init Container, Sidecar, Adapter, Ambassador with concrete YAML examples for this platform's services
- `references/keda-scaling-config.md` — KEDA `ScaledObject` examples for Redpanda consumer lag, HTTP scaling, and scale-to-zero configuration
