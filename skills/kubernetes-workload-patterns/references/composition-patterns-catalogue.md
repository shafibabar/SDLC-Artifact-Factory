# Pod Composition Patterns Catalogue — kubernetes-workload-patterns

This reference is self-contained. It documents all four structural pod composition patterns (Init Container, Sidecar, Adapter, Ambassador) with concrete YAML examples drawn from this platform's actual services.

---

## Pattern 1: Init Container

### Definition

One or more containers that **run to completion** before any application container in the pod starts. Init containers run sequentially (each must exit 0 before the next starts). The application containers only start after all Init containers have succeeded.

### Decision Criteria — Use Init Containers When:

| Trigger | Example |
|---|---|
| A secret must be present before the app starts | Vault Agent pulling a DB password into `/vault/secrets/` before the app reads it |
| A schema must be at the correct version before the app connects | `golang-migrate up` before `compliance-engine` starts |
| A dependency must be reachable before the app attempts connection | Wait-for-it loop polling Postgres/Redpanda readiness endpoint |
| A config file must be rendered before the app reads it | A template Init Container writing the final config to a shared volume |

### Do NOT Use Init Containers For:

- Long-running companions (Linkerd proxy, log forwarder) — these are Sidecars.
- Work that can run concurrently with startup without risk of race.
- Anything that should run on a schedule (use CronJob or a background goroutine).

### YAML Pattern: Vault Secret Retrieval

```yaml
spec:
  volumes:
    - name: vault-secrets
      emptyDir:
        medium: Memory   # in-memory only — never touches node disk
  initContainers:
    - name: vault-agent-init
      image: hashicorp/vault:1.15
      command:
        - vault
        - agent
        - -config=/vault/config/agent.hcl
        - -exit-after-auth   # exit after auth + secret write; do not run as a daemon
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
        - name: vault-agent-config
          mountPath: /vault/config
      env:
        - name: VAULT_ADDR
          value: "http://vault.infra.svc.cluster.local:8200"
  containers:
    - name: compliance-engine
      volumeMounts:
        - name: vault-secrets
          mountPath: /secrets
          readOnly: true
      # app reads /secrets/db-password — populated by the init container
```

### YAML Pattern: Schema Migration (golang-migrate)

```yaml
spec:
  initContainers:
    - name: schema-migrate
      image: ghcr.io/acme/data-estate/schema-migrator:sha256:abc123
      command: ["/migrate", "-database", "$(DATABASE_URL)", "-path", "/migrations", "up"]
      envFrom:
        - secretRef:
            name: postgres-credentials
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          memory: 128Mi
  containers:
    - name: compliance-engine
      # starts only after schema-migrate exits 0
```

### YAML Pattern: Dependency Health Wait

```yaml
  initContainers:
    - name: wait-for-redpanda
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          until wget -qO- http://redpanda-headless.$(POD_NAMESPACE).svc.cluster.local:9644/v1/status/ready; do
            echo "Waiting for Redpanda..."
            sleep 3
          done
      env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
      resources:
        requests: { cpu: 10m, memory: 16Mi }
        limits: { memory: 32Mi }
```

---

## Pattern 2: Sidecar

### Definition

A second container co-located in the same pod as the main application container. The two containers share:
- **Network namespace** — they communicate via `localhost`; no Service or TLS needed between them.
- **Process namespace** (optional) — when `shareProcessNamespace: true` is set.
- Mounted volumes (explicitly declared).

The sidecar enhances the main container's capabilities (logging, metrics emission, proxy) **without modifying the main container**.

### Kubernetes 1.29+ Native Sidecar (Required for Clusters ≥ 1.29)

Declare the sidecar in `initContainers` with `restartPolicy: Always`. Kubernetes 1.29+ treats this as a native sidecar container:
- Starts **before** app containers (like a regular Init Container).
- Remains **running** while app containers run (unlike a regular Init Container, which exits before app containers start).
- Does **not** block pod readiness on its own readiness check.
- Receives `SIGTERM` **after** app containers have exited (correct graceful shutdown ordering).

```yaml
spec:
  initContainers:
    - name: fluent-bit-sidecar
      image: fluent/fluent-bit:3.0
      restartPolicy: Always    # <-- this makes it a native sidecar (K8s 1.29+)
      volumeMounts:
        - name: varlog
          mountPath: /var/log/app
      resources:
        requests: { cpu: 10m, memory: 32Mi }
        limits: { memory: 64Mi }
  containers:
    - name: estate-scanner
      volumeMounts:
        - name: varlog
          mountPath: /var/log/app
```

On clusters < 1.29, declare the Fluent Bit container in `containers:` alongside the main container — it starts concurrently (no ordering guarantee) and stops when the pod terminates.

### YAML Pattern: OTel Collector Sidecar

Used when per-pod metric cardinality matters or pod lifecycle must be independent of node-level collection. The app exports to `localhost:4317` — no TLS, no service mesh hop.

```yaml
spec:
  initContainers:
    - name: otel-collector
      image: otel/opentelemetry-collector-contrib:0.100.0
      restartPolicy: Always    # native sidecar
      args:
        - "--config=/etc/otel/config.yaml"
      ports:
        - containerPort: 4317   # OTLP gRPC
        - containerPort: 4318   # OTLP HTTP
      volumeMounts:
        - name: otel-config
          mountPath: /etc/otel
      resources:
        requests: { cpu: 50m, memory: 64Mi }
        limits: { memory: 256Mi }
  volumes:
    - name: otel-config
      configMap:
        name: otel-collector-sidecar-config
  containers:
    - name: estate-scanner
      env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://localhost:4317"
```

The `otel-collector-sidecar-config` ConfigMap sets the OTel Collector to receive on `0.0.0.0:4317` and export to the DaemonSet Collector (or directly to Tempo/Prometheus).

### OTel Collector: Sidecar vs DaemonSet Criterion

| Factor | Sidecar Collector | DaemonSet Collector |
|---|---|---|
| Per-pod cardinality | Each pod has its own collector — telemetry is pod-scoped from the start | All pods on a node share one collector — pod identity is a label, not a process boundary |
| Resource cost | One Collector process per pod — multiplies with replica count | One Collector per node — fixed node-level cost |
| Pod lifecycle independence | Pod can be rescheduled to any node without reconfiguring the collector | If the DaemonSet pod fails, all pods on that node lose their collector |
| Recommended for | High-cardinality services where per-pod trace/metric isolation is business-critical | Standard platform deployments where resource efficiency is the priority |

**Default for this platform:** DaemonSet Collector. Use Sidecar only for services with explicit per-pod cardinality requirements documented in their ADR.

### Linkerd Proxy (Auto-Injected Sidecar)

Linkerd's proxy sidecar is **not** declared in the pod spec. The Linkerd control plane's admission webhook injects it automatically when the pod annotation is present:

```yaml
metadata:
  annotations:
    linkerd.io/inject: enabled
```

Do not add a Linkerd container manually. The injected proxy runs alongside the main container, handles mTLS for all inbound and outbound traffic, and exposes per-route metrics on `:4191`.

---

## Pattern 3: Adapter

### Definition

An Adapter is a sidecar whose sole purpose is **translating the main container's output interface** into a standard format the platform's collection pipeline expects. The main container's code is not modified.

### When to Use

Use an Adapter when:
- A service emits logs in a legacy or proprietary format that cannot be parsed by the platform's log pipeline (Fluent Bit, Loki).
- A third-party binary produces metrics in a non-Prometheus format.
- Changing the main container's output format would require forking the third-party binary or a significant refactor.

When the main container **can** be modified, prefer modifying it over adding an Adapter — adding a sidecar multiplies resource cost and operational complexity.

### YAML Pattern: Log Format Adapter

```yaml
spec:
  volumes:
    - name: log-pipe
      emptyDir: {}
  initContainers:
    - name: log-adapter
      image: ghcr.io/acme/data-estate/log-adapter:1.0.0
      restartPolicy: Always
      args:
        - "--input=/logs/app.log"
        - "--format=json"
        - "--output=stdout"
      volumeMounts:
        - name: log-pipe
          mountPath: /logs
      resources:
        requests: { cpu: 10m, memory: 16Mi }
        limits: { memory: 32Mi }
  containers:
    - name: legacy-worker
      volumeMounts:
        - name: log-pipe
          mountPath: /logs
      # writes /logs/app.log in a proprietary format; adapter reads it and emits JSON on stdout
```

---

## Pattern 4: Ambassador

### Definition

An Ambassador is a sidecar that **proxies outbound requests** from the main container to an external service. It handles concerns the main container cannot be easily instrumented for: retries, circuit breaking, protocol translation, mTLS to an external endpoint.

### When to Use

Use an Ambassador when:
- A third-party binary makes outbound HTTP calls and cannot be configured to use retry/circuit-break logic.
- A service makes calls to an external API that requires mTLS client certificates the main container cannot manage.
- The main container uses a non-HTTP protocol to an external endpoint, and translation is required before the platform's mesh can handle it.

For services that are Go binaries on this platform, **prefer implementing retry and circuit-break logic in the Go code** (using `net/http` middleware or a library like `go-resilience`) over adding an Ambassador. An Ambassador is the fallback for code you cannot modify.

### YAML Pattern: Ambassador for a Legacy Binary

```yaml
spec:
  initContainers:
    - name: envoy-ambassador
      image: envoyproxy/envoy:v1.29
      restartPolicy: Always
      args:
        - "--config-path"
        - "/etc/envoy/envoy.yaml"
      volumeMounts:
        - name: envoy-config
          mountPath: /etc/envoy
      ports:
        - containerPort: 8001   # admin port
      resources:
        requests: { cpu: 50m, memory: 64Mi }
        limits: { memory: 128Mi }
  volumes:
    - name: envoy-config
      configMap:
        name: envoy-ambassador-config
  containers:
    - name: legacy-binary
      env:
        - name: UPSTREAM_ENDPOINT
          value: "http://localhost:8080"   # traffic goes to Envoy, not directly upstream
```

The Envoy config routes `localhost:8080` to the real upstream with retry policy, timeout, and circuit breaking.

---

## Multi-Container Pod Decision Checklist

Before adding any second container to a pod, apply this checklist:

| Question | Answer Required |
|---|---|
| Do both containers share a lifecycle — is it harmful to run one without the other? | Yes |
| Would putting them in separate pods connected by a Service break their function? | Yes |
| Are they sharing data via a volume or localhost communication that would be impossible across pod boundaries? | Yes (for volume sharing) OR the localhost/loopback requirement is the reason |

If any answer is "No", the containers belong in **separate pods** connected via Kubernetes Service DNS. The rule exists because co-located containers cannot be independently scaled, scheduled, or upgraded — every coupling reduces operational flexibility.

---

## Pattern Selection Quick Reference

| You need | Pattern | Kubernetes resource |
|---|---|---|
| Pre-start setup (secrets, migration, wait) | Init Container | `initContainers` (regular) |
| Co-located, long-running companion | Sidecar (K8s 1.29+) | `initContainers` with `restartPolicy: Always` |
| Translate output format of a third-party container | Adapter (subtype of Sidecar) | `initContainers` with `restartPolicy: Always` |
| Proxy outbound calls for un-instrumentable container | Ambassador (subtype of Sidecar) | `initContainers` with `restartPolicy: Always` |
| Auto-injected mesh proxy | Linkerd (annotation, not a spec entry) | Pod annotation `linkerd.io/inject: enabled` |
