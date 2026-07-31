# KEDA Scaling Configuration — kubernetes-workload-patterns

This reference is self-contained. It provides concrete `ScaledObject` YAML for this platform's Redpanda consumer lag scaling, HTTP-based scaling, and scale-to-zero configuration. Prerequisites and operational constraints are included.

---

## What KEDA Is and When to Use It

**KEDA (Kubernetes Event-Driven Autoscaler)** is a CNCF project that extends Kubernetes' HorizontalPodAutoscaler to scale workloads based on external event sources — queue depth, consumer group lag, cron schedule, HTTP request rate — rather than only CPU/memory utilisation.

**Use KEDA when:**
- A consumer service's busyness is invisible to CPU metrics: a Redpanda consumer parked at zero CPU while a backlog of 500,000 messages accumulates behind it is under no CPU pressure but is critically under-scaled.
- The service should **scale to zero** during idle periods (weekend batch consumer, off-hours report generator) and start from zero when messages arrive.
- Scaling trigger is proportional to an external metric the service consumes (messages per second, queue depth, HTTP RPS from an ingress controller).

**Do not use KEDA when:**
- The workload is a CPU-bound request handler (compliance-engine, estate-scanner API) — CPU-HPA is simpler and the signal is correct.
- The workload is a DaemonSet — KEDA does not scale DaemonSets; they scale by node count.
- The workload is a StatefulSet requiring ordered pod scaling — KEDA can scale StatefulSets but the implications for quorum must be considered; consult the relevant Operator's documentation first.

---

## Prerequisites

KEDA is **not** bundled with Kubernetes. It requires:
1. Installation via the official KEDA Helm chart (`keda/keda` from `https://kedacore.github.io/charts`).
2. KEDA installs its own `ScaledObject`, `ScaledJob`, and `TriggerAuthentication` CRDs.
3. The `opentofu-module` that provisions the cluster must include the KEDA Helm release — this is a deliberate provisioning decision, not a YAML pattern applied ad-hoc.

```hcl
# opentofu: keda.tf (cluster-level addon, not tenant-level)
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.14.2"
  namespace  = "keda"
  create_namespace = true

  set {
    name  = "watchNamespace"
    value = ""  # empty string = watch all namespaces
  }
}
```

---

## Pattern 1: Redpanda Consumer Lag Scaling (go-event-consumer)

This is the primary KEDA use case on this platform. `go-event-consumer` should idle to zero when its consumer group lag is zero and scale up proportionally to lag.

### TriggerAuthentication (cluster-scoped secret reference)

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-redpanda-auth
  namespace: tenant-acme
spec:
  secretTargetRef:
    - parameter: sasl_password
      name: redpanda-keda-credentials
      key: password
    - parameter: tls_ca_cert
      name: redpanda-keda-credentials
      key: ca.crt
```

The `redpanda-keda-credentials` Secret is provisioned by the `opentofu-module`'s secret management (not stored in Git).

### ScaledObject: Consumer Lag (go-event-consumer)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: go-event-consumer
  namespace: tenant-acme
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: go-event-consumer
  minReplicaCount: 0          # scale to zero when lag is zero
  maxReplicaCount: 20         # bounded by ResourceQuota for the tenant
  cooldownPeriod: 300         # seconds before scaling down after lag clears — prevents flapping
  pollingInterval: 15         # seconds between lag checks
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300   # 5-minute stabilisation before scaling down
          policies:
            - type: Pods
              value: 2
              periodSeconds: 60             # remove at most 2 replicas per minute
        scaleUp:
          stabilizationWindowSeconds: 0     # scale up immediately — backlog is an emergency
          policies:
            - type: Pods
              value: 4
              periodSeconds: 15             # add up to 4 replicas per 15s
  triggers:
    - type: kafka                           # Kafka-compatible — Redpanda speaks the Kafka protocol
      metadata:
        bootstrapServers: "redpanda-0.redpanda-headless.tenant-acme.svc.cluster.local:9092"
        consumerGroup: go-event-consumer-group
        topic: domain-events
        lagThreshold: "100"                 # scale when lag > 100 messages
        activationLagThreshold: "10"        # scale FROM zero when lag > 10 (prevents thrash at zero boundary)
        offsetResetPolicy: latest
        sasl: plaintext
        tls: enable
        allowIdleConsumers: "false"
      authenticationRef:
        name: keda-redpanda-auth
```

**Key parameters explained:**
- `lagThreshold: "100"` — KEDA adds one replica for every 100 messages of lag (linearly). At lag=1000, expect ~10 replicas.
- `activationLagThreshold: "10"` — prevents constant scale-from-zero thrash on low-volume topics; only activates from zero when lag genuinely exceeds 10.
- `cooldownPeriod: 300` — waits 5 minutes after lag clears before scaling to zero; covers burst patterns where the consumer drains quickly then more messages arrive.
- `scaleUp.stabilizationWindowSeconds: 0` — scale up immediately; a growing backlog is never acceptable to ride out for a stabilisation window.
- `scaleDown.stabilizationWindowSeconds: 300` — conservative; ensures the consumer isn't scaled down in the middle of a processing burst.

### Corresponding Deployment (the scale target)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-event-consumer
  namespace: tenant-acme
spec:
  replicas: 1                 # initial value; KEDA takes control immediately and overrides this
  selector:
    matchLabels:
      app.kubernetes.io/name: go-event-consumer
  template:
    metadata:
      labels:
        app.kubernetes.io/name: go-event-consumer
      annotations:
        linkerd.io/inject: enabled
    spec:
      serviceAccountName: go-event-consumer
      terminationGracePeriodSeconds: 60   # consumer must finish processing in-flight messages
      containers:
        - name: go-event-consumer
          image: ghcr.io/acme/data-estate/go-event-consumer:sha256:abc123
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { memory: 256Mi }
          env:
            - name: KAFKA_BROKERS
              value: "redpanda-0.redpanda-headless.tenant-acme.svc.cluster.local:9092"
            - name: CONSUMER_GROUP
              value: go-event-consumer-group
            - name: TOPIC
              value: domain-events
```

`terminationGracePeriodSeconds: 60` is longer than the default 30 because a consumer that is mid-processing a batch must have time to commit its offsets and close the consumer group cleanly before SIGKILL. If the Go consumer has a configurable drain timeout, set `terminationGracePeriodSeconds` to that value + 5s buffer.

---

## Pattern 2: HTTP Request Rate Scaling (estate-scanner API)

For request-serving workloads where request rate is a more precise signal than CPU — or where the service needs to scale from zero during off-hours.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: estate-scanner-http
  namespace: tenant-acme
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: estate-scanner
  minReplicaCount: 1          # keep 1 replica running (no cold-start for API traffic)
  maxReplicaCount: 10
  cooldownPeriod: 180
  pollingInterval: 30
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.monitoring.svc.cluster.local:9090
        metricName: http_requests_per_second
        query: |
          sum(rate(http_server_requests_total{namespace="tenant-acme",service="estate-scanner"}[2m]))
        threshold: "50"         # scale when RPS > 50; one replica handles 50 RPS at target utilisation
        activationThreshold: "5"
```

**`minReplicaCount: 1`** — unlike the consumer pattern, the estate-scanner API must not scale to zero; cold-start latency is user-visible. The `minReplicaCount: 0` pattern is reserved for batch consumers and background workers.

---

## Pattern 3: Cron-Triggered Scaling (Scheduled Batch)

For workloads that should scale up before a scheduled peak and return to zero after. This combines KEDA's cron trigger with scale-to-zero.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cache-warmer-scheduled
  namespace: tenant-acme
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cache-warmer
  minReplicaCount: 0
  maxReplicaCount: 5
  cooldownPeriod: 600
  triggers:
    - type: cron
      metadata:
        timezone: UTC
        start: "30 7 * * 1-5"   # 07:30 UTC Monday–Friday (pre-business-hours warm-up)
        end:   "00 8 * * 1-5"   # 08:00 UTC (30-minute warm-up window)
        desiredReplicas: "3"
```

---

## ScaledJob: Batch Processing (One-Shot Consumers)

For batch workloads where each Job pod processes one unit of work and exits — rather than a long-running consumer that processes many messages. This is appropriate when message processing is long (minutes), stateful per-message, or requires isolation between messages.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: pdf-processor
  namespace: tenant-acme
spec:
  jobTargetRef:
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: pdf-processor
            image: ghcr.io/acme/data-estate/pdf-processor:sha256:abc123
            resources:
              requests: { cpu: 500m, memory: 512Mi }
              limits: { memory: 1Gi }
  minReplicaCount: 0
  maxReplicaCount: 10
  pollingInterval: 10
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: "redpanda-0.redpanda-headless.tenant-acme.svc.cluster.local:9092"
        consumerGroup: pdf-processor-group
        topic: pdf-processing-requests
        lagThreshold: "1"       # one Job per message in queue
      authenticationRef:
        name: keda-redpanda-auth
```

`lagThreshold: "1"` creates one Job per message — KEDA reads the lag and creates that many Jobs up to `maxReplicaCount`. Each Job processes one message and exits. This is appropriate for long-running, isolated per-message work. For high-throughput short-message work, use the Deployment + ScaledObject pattern instead.

---

## Operational Notes

### Scale-to-Zero Cold Start

When `minReplicaCount: 0` is set and the Deployment has zero running replicas, the first message after a quiet period triggers KEDA to create one replica. The consumer is unavailable for the duration of the pod startup (probe checks, container init). For this platform's Go consumers, expect 5–15 seconds of startup before the consumer joins the consumer group and begins processing. Messages accumulate in Redpanda during this window — they are not lost.

If cold-start latency is unacceptable for a particular topic's SLO, set `minReplicaCount: 1` and accept the cost of one idle replica. Document this decision in the service's ADR.

### HPA and KEDA Coexistence

**Do not create both an HPA and a ScaledObject targeting the same Deployment.** KEDA creates and manages its own HPA under the hood. Two HPAs targeting the same Deployment will conflict and produce unpredictable behaviour. If migrating from a hand-authored HPA to KEDA, delete the HPA before applying the ScaledObject.

### ResourceQuota Interaction

KEDA respects `maxReplicaCount` but not directly the namespace `ResourceQuota`. If KEDA tries to create replicas that would breach the quota, the pod creation fails and KEDA logs an error. Always set `maxReplicaCount` conservatively within the tenant's provisioned ResourceQuota for the service. The `opentofu-module` for tenant provisioning documents the per-tier replica budgets.

### Scaling Behaviour Defaults (when `advanced.horizontalPodAutoscalerConfig.behavior` is omitted)

| Direction | Default stabilisationWindow | Default policy |
|---|---|---|
| Scale up | 0 seconds | 100% of current replicas per 15 seconds |
| Scale down | 300 seconds | 100% of current replicas per 15 seconds |

The 5-minute scale-down stabilisation window is a safe default but may be too conservative for consumers with short bursts. Tune the `scaleDown.stabilizationWindowSeconds` per service based on observed traffic patterns.
