# Controller Type Decision Table — kubernetes-workload-patterns

This reference is self-contained. It applies the controller decision criteria from `SKILL.md` to every service in this platform's stack, documents anti-patterns with their consequences, and gives the precise criteria for each controller type.

---

## Complete Controller Decision Table

| Service | Controller | Criterion | Notes |
|---|---|---|---|
| estate-scanner | Deployment | Stateless; any replica handles any crawl request via work queue | Scale via KEDA ScaledObject (queue-depth) if crawl scheduling moves to Redpanda |
| compliance-engine | Deployment | Stateless request handler; replicas are interchangeable | CPU-HPA appropriate — latency correlates with CPU on rule evaluation workloads |
| entity-extractor | Deployment + KEDA | Stateless consumer; scale must track Redpanda consumer lag, not CPU | See `references/keda-scaling-config.md` |
| go-event-consumer | Deployment + KEDA | Queue consumer that should idle to zero when lag is zero | KEDA `ScaledObject` with `minReplicaCount: 0` |
| Redpanda | StatefulSet (Operator) | Per-broker persistent storage (WAL volumes); stable pod DNS for inter-broker comms | Use the Redpanda Operator — do not author raw StatefulSet manifests |
| Zookeeper | StatefulSet (Operator) | Quorum requires stable pod identity; ordered startup is required | Use the official Bitnami or Confluent Operator chart |
| PostgreSQL | StatefulSet (Operator) | Per-instance data volume; primary-replica identity must be stable | Use the CloudNativePG Operator (CNCF) |
| Fluent Bit | DaemonSet | Must run on every node to collect node-level container logs; Deployment cannot guarantee one-per-node | Node-scoped log collection is undefined behaviour on a Deployment |
| OTel Collector (node-level) | DaemonSet | Collects from all pods on a node via hostPath or OTLP push; one per node is the correct cardinality | When per-pod isolation matters, use Sidecar variant instead |
| node-exporter | DaemonSet | Exposes per-node hardware and OS metrics — meaningless as a Deployment | Standard Prometheus Helm chart deploys this as a DaemonSet |
| Linkerd CNI | DaemonSet | Must install CNI plugin configuration on every node; DaemonSet is the only correct type | Auto-managed by Linkerd Helm chart |
| schema-migration | Job | One-time run-to-completion; terminates with exit 0 on success | Helm pre-install/pre-upgrade hook pattern; never run as an Init Container in the service's own pod if it mutates shared state |
| nightly-compliance-report | CronJob | Scheduled, bounded, run-to-completion; `schedule: "0 2 * * *"` | Set `concurrencyPolicy: Forbid` to prevent overlapping runs |
| cache-warmer | CronJob | Periodic, bounded; runs before peak traffic window | `successfulJobsHistoryLimit: 3`, `failedJobsHistoryLimit: 3` |
| estate-scanner (canary deploy) | Argo Rollout | Canary analysis against error-rate SLO before full cutover | Requires Argo Rollouts controller installed; replaces the Deployment object |

---

## Decision Criteria — Precise Definitions

### Deployment

**The default.** Use Deployment when all three of these hold:
1. Any running replica can serve any request (stateless).
2. Pod identity does not matter to the service's correctness (not keyed to a pod name, hostname, or volume).
3. Replicas can start and stop in any order without business-logic consequence.

A Deployment's pods have **no stable identity** — they get random suffixes (`estate-scanner-6b4f9d8c7-xzpq2`) that change on every rollout. Any service that depends on a stable hostname is architecturally misusing a Deployment.

### StatefulSet

Use when **any one** of these holds:
1. Each pod needs a stable, predictable network identity (pods get `<name>-<ordinal>.<svc>.<ns>.svc.cluster.local`).
2. Each pod needs its own persistent storage volume that survives pod restarts and is never shared with another pod (`volumeClaimTemplates`).
3. Ordered startup/shutdown is required by the distributed protocol (Raft quorum, Zookeeper ensemble startup).

**Headless Service requirement:** A StatefulSet's per-pod DNS works only with a headless Service (`clusterIP: None`). Non-headless Services load-balance across pods and destroy the per-pod DNS guarantee. Always pair a StatefulSet with a headless Service.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redpanda-headless
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: redpanda
  ports:
    - name: kafka
      port: 9092
```

With this, pod `redpanda-0` is reachable at `redpanda-0.redpanda-headless.<namespace>.svc.cluster.local` — the broker address every client is configured to use.

**Operator first:** For Redpanda, PostgreSQL, and Zookeeper, a production-quality Operator encodes the operational knowledge (cluster scaling, backup, failover, version upgrades) that raw StatefulSet YAML cannot express. Always prefer an existing, well-maintained Operator over a hand-rolled StatefulSet for these systems.

#### The Operator Ladder — three options, in this priority order

Stateful infrastructure is provisioned by taking the **first** of these that applies. Never skip a rung.

| Rung | Use when | Examples | Cost |
|---|---|---|---|
| **1. Existing Operator** | A well-maintained Operator covers the domain | CloudNativePG or Zalando/CrunchyData for PostgreSQL · Redpanda Operator · Strimzi for Kafka-compatible brokers · Prometheus Operator for Prometheus/Alertmanager/ServiceMonitors/recording rules · cert-manager for TLS certificate lifecycle | Adoption only. Do not replicate its behaviour with raw manifests or Helm hooks. |
| **2. Helm chart + lifecycle hooks** | No Operator exists, the operational domain is only moderately complex, and setup is genuinely **one-time** — schema seeding, key provisioning | A small internal stateful component whose scaling and upgrade steps are acceptable as documented manual procedures | Manual scale/upgrade runbooks. Acceptable only while those procedures stay rare — a hook procedure run repeatedly is toil (`platform-engineering-design`). |
| **3. Custom Operator** | **Both** hold: (a) no existing Operator covers the domain, **and** (b) the operational knowledge requires a continuous **reconciliation loop** — desired-state enforcement, automatic failover, dynamic reconfiguration from cluster state — that install-time hooks structurally cannot express, because hooks run once and never again | Genuinely novel stateful infrastructure | High and ongoing: controller-runtime, CRD design, status subresource, event queue mechanics, and its own upgrade story. **Record the decision in an ADR and obtain approval before starting.** |

**The rung-2/rung-3 test is "once or continuously", not "simple or complex".** A Helm post-install hook fires at install time and is then gone; if the requirement is *continuous* convergence, no quantity of hooks will express it and rung 2 is the wrong answer regardless of how simple the domain looks. Conversely, complexity alone does not justify rung 3 — a complicated but genuinely one-time setup belongs on rung 2.

**Anti-pattern — building a custom Operator because an existing one is imperfect.** Contributing a fix upstream is almost always cheaper than owning a controller forever. Rung 3 is a permanent engineering commitment, not a sprint.

### DaemonSet

Use when the service is **node-scoped infrastructure** — it collects or modifies something that only exists per-node (filesystem paths, kernel interfaces, CNI configuration, per-node hardware metrics).

**Why not a Deployment with high replica count?**
- A Deployment schedules replicas according to bin-packing and resource availability — there is no guarantee of one-per-node.
- If a node is added, the Deployment does not automatically place a new replica there.
- A DaemonSet guarantees exactly one pod per node (subject to `nodeSelector` / `tolerations`), and automatically creates/removes pods as nodes join/leave the cluster.

**Node selection:** Use `nodeSelector` to restrict the DaemonSet to specific node pools (e.g., skip the control-plane nodes for log forwarders). Use `tolerations` to schedule onto nodes with taints (e.g., dedicated GPU nodes that need the same monitoring agent).

### Job

Use when work has a defined completion state (`exitCode: 0`) and should never repeat automatically.

Key fields:
- `completions`: number of successful pod completions required.
- `parallelism`: how many pods run concurrently.
- `backoffLimit`: retries before the Job is marked failed (default 6 — usually too high for schema migrations; set to 2).
- `activeDeadlineSeconds`: hard time budget; the Job is killed and marked failed after this (prevents runaway migrations from holding locks indefinitely).

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: schema-migration-v42
spec:
  backoffLimit: 2
  activeDeadlineSeconds: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: ghcr.io/acme/data-estate/schema-migrator:sha256:abc123
          command: ["/migrate", "-database", "$(DATABASE_URL)", "up"]
          envFrom:
            - secretRef:
                name: postgres-url
```

`restartPolicy: Never` (not `OnFailure`) — a failed migration should not be retried automatically; the Job's `backoffLimit` governs retries at the Job level, giving time to inspect logs before the next attempt.

### CronJob

Use when work is bounded (has a completion state), recurs on a schedule, and the scheduled time is meaningful.

Key fields:
- `schedule`: standard five-field cron expression (UTC).
- `concurrencyPolicy: Forbid` — prevents a new run from starting if the previous one is still running. Use `Allow` only when runs are truly independent and overlap is safe. Never use `Replace` on data-modifying jobs.
- `successfulJobsHistoryLimit: 3`, `failedJobsHistoryLimit: 3` — retain enough history to diagnose failures without accumulating unbounded Job objects.
- `startingDeadlineSeconds`: if the CronJob controller was down at the scheduled time, it will only catch up within this window. Set to a value shorter than the job's `activeDeadlineSeconds`.

### Argo Rollout

Use **instead of** a Deployment when the service's deployment strategy requires:
- **Canary delivery** with automated traffic splitting (e.g., 10% → 25% → 50% → 100%) and analysis against a live success-rate metric before each step.
- **Blue-green delivery** with an explicit promotion step and automated rollback if the analysis threshold fails.

An Argo Rollout is a drop-in replacement for a Deployment — it uses the same pod spec, same selector labels, same Service objects. The `strategy` section replaces `strategy: type: RollingUpdate`. The Argo Rollouts controller must be installed cluster-wide.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: compliance-engine
spec:
  replicas: 4
  selector:
    matchLabels:
      app.kubernetes.io/name: compliance-engine
  template:         # identical to a Deployment's pod spec
    metadata:
      labels:
        app.kubernetes.io/name: compliance-engine
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: compliance-engine
        - setWeight: 50
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate
```

---

## Anti-Patterns

| Anti-Pattern | Consequence | Correct Pattern |
|---|---|---|
| Deployment for a node-scoped agent | New nodes don't get the agent; existing replicas double up on some nodes | DaemonSet |
| Deployment for Redpanda/Postgres | Pod restarts lose the identity; clients fail to reconnect to the correct broker/primary | StatefulSet (via Operator) |
| StatefulSet for a stateless service | Ordered startup/shutdown, stable identity overhead with no benefit; slower rollouts | Deployment |
| Deployment instead of Argo Rollout for canary | Kubernetes `RollingUpdate` has no analysis gate; bad versions propagate to 100% before failure is detected | Argo Rollout with analysis |
| Job with `restartPolicy: OnFailure` for schema migration | A failed migration re-runs immediately, potentially applying a partial migration twice | `restartPolicy: Never`; use `backoffLimit` at Job level |
| CronJob with `concurrencyPolicy: Allow` for data mutations | Overlapping runs modify the same data concurrently; data integrity depends on the job's internal locking | `concurrencyPolicy: Forbid` |
| KEDA instead of HPA for a CPU-bound stateless API | KEDA adds operational complexity for a problem CPU-HPA already solves well | HPA with CPU target |
| HPA instead of KEDA for a Redpanda consumer | CPU is near-zero when the backlog is large but processing has stalled; HPA sees no signal | KEDA with Kafka/Redpanda scaler |

---

## Controller Frontmatter Quick Reference

| Controller | API Group | Kind |
|---|---|---|
| Deployment | `apps/v1` | `Deployment` |
| StatefulSet | `apps/v1` | `StatefulSet` |
| DaemonSet | `apps/v1` | `DaemonSet` |
| Job | `batch/v1` | `Job` |
| CronJob | `batch/v1` | `CronJob` |
| Argo Rollout | `argoproj.io/v1alpha1` | `Rollout` |
| KEDA ScaledObject | `keda.sh/v1alpha1` | `ScaledObject` |
