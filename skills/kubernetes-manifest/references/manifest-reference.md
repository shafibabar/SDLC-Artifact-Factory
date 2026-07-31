# Kubernetes Manifest Reference

Self-contained reference for the `kubernetes-manifest` skill. Contains full worked examples, the Output Format template, and decision guides for patterns named in the skill body. Usable without SKILL.md in context.

---

## terminationGracePeriodSeconds Calculation Guide

**Rule:** `terminationGracePeriodSeconds` = app drain timeout + 5 seconds minimum buffer.

**Why 5 seconds?** After Kubernetes marks a pod terminating, kube-proxy must update iptables rules on every node, and the Linkerd mesh proxy must drain its connection pool. This propagation takes 1–3 seconds in a well-provisioned cluster. The 5-second buffer absorbs worst-case propagation plus clock drift, ensuring the `preStop` sleep has finished and all routing layers have stopped sending before SIGTERM arrives.

**Consequence of misalignment:** If `terminationGracePeriodSeconds` is less than the application's drain deadline, Kubernetes sends SIGKILL when the grace period expires. SIGKILL terminates the container immediately — the Go HTTP server's `srv.Shutdown` goroutine is killed mid-drain, and in-flight requests receive a TCP RST. This appears as connection errors in the client and has no log entry from the application (the process is gone). The error is silent until load tests or SLO burn-rate alerts fire.

**Standard Go service (25s drain deadline):**

```yaml
terminationGracePeriodSeconds: 30    # 25s drain + 5s buffer
containers:
  - lifecycle:
      preStop:
        sleep: { seconds: 3 }        # endpoint-removal propagation window
```

**Service with longer drain (e.g., streaming service, 60s drain):**

```yaml
terminationGracePeriodSeconds: 65    # 60s drain + 5s buffer
containers:
  - lifecycle:
      preStop:
        sleep: { seconds: 5 }        # larger cluster = more propagation time
```

**When preStop is needed:** The `preStop` hook fires before the kubelet sends SIGTERM. Use it when the application cannot handle SIGTERM fast enough — for example, when the app starts accepting new requests between "pod marked terminating" and "SIGTERM received" because the routing layer hasn't caught up yet. The sleep in `preStop` is not subtracted from `terminationGracePeriodSeconds`; the total wall-clock time from "pod marked terminating" to SIGKILL is `terminationGracePeriodSeconds`. Size accordingly: `preStop sleep + app drain ≤ terminationGracePeriodSeconds - 2s`.

---

## Init Container Worked Examples

### Example 1: Schema Migration Init Container

Runs `go-migration`'s `migrate up` before the API container starts. If migration fails, the init container exits non-zero and the pod does not start — the rollout stalls rather than deploying a broken schema.

```yaml
initContainers:
  - name: migrate
    image: ghcr.io/acme/data-estate/estate-scanner@sha256:abc123   # same digest as app container
    command: ["/app/migrate", "up"]
    env:
      - name: DATABASE_URL
        valueFrom:
          secretKeyRef:
            name: estate-scanner-db
            key: url
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: ["ALL"] }
    resources:
      requests: { cpu: 50m, memory: 64Mi }
      limits: { memory: 128Mi }
```

### Example 2: Vault Secret Pull into Shared Volume

Pulls a secret from Vault into an `emptyDir` volume before the app container starts. The app reads the file at startup; no Vault SDK or runtime token needed in the app process.

```yaml
volumes:
  - name: vault-secrets
    emptyDir:
      medium: Memory          # never touches disk
initContainers:
  - name: vault-pull
    image: hashicorp/vault:1.16
    command:
      - sh
      - -c
      - |
        vault login -method=kubernetes role=estate-scanner
        vault kv get -field=api_key secret/data-estate/scanner > /secrets/api_key
    env:
      - name: VAULT_ADDR
        value: http://vault.vault.svc.cluster.local:8200
    volumeMounts:
      - name: vault-secrets
        mountPath: /secrets
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false   # vault writes its token cache
      capabilities: { drop: ["ALL"] }
    resources:
      requests: { cpu: 50m, memory: 64Mi }
      limits: { memory: 128Mi }
containers:
  - name: estate-scanner
    volumeMounts:
      - name: vault-secrets
        mountPath: /run/secrets
        readOnly: true
```

### Example 3: Native Sidecar (Kubernetes 1.29+)

An OTel Collector declared as a native sidecar using `restartPolicy: Always` in `initContainers[]`. It starts before app containers, stays running while they run, and is restarted independently if it crashes. This supersedes the pre-1.29 workaround of using a long-running init container.

```yaml
initContainers:
  - name: otel-collector
    image: otel/opentelemetry-collector-contrib:0.100.0
    restartPolicy: Always             # makes this a native sidecar (k8s 1.29+)
    args: ["--config=/conf/otel-collector-config.yaml"]
    volumeMounts:
      - name: otel-config
        mountPath: /conf
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: ["ALL"] }
    resources:
      requests: { cpu: 50m, memory: 64Mi }
      limits: { memory: 128Mi }
volumes:
  - name: otel-config
    configMap: { name: otel-collector-config }
```

The app container exports to `localhost:4317` (no TLS) because the sidecar shares the pod's network namespace. The sidecar forwards to the cluster-level OTel backend with TLS.

---

## Full Worked Example — estate-scanner Deployment

Complete rendered workload for `estate-scanner` in `tenant-acme`'s namespace. This is the shape every Deployment must converge to; only values (image digest, resource sizes, network allow targets) differ per service.

```yaml
# 1. ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: estate-scanner
  namespace: tenant-acme
  labels:
    app.kubernetes.io/name: estate-scanner
    app.kubernetes.io/part-of: data-estate-platform
    tenant: acme
automountServiceAccountToken: false
---
# 2. Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: estate-scanner
  namespace: tenant-acme
  labels:
    app.kubernetes.io/name: estate-scanner
    app.kubernetes.io/part-of: data-estate-platform
    tenant: acme
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: estate-scanner
  template:
    metadata:
      labels:
        app.kubernetes.io/name: estate-scanner
        app.kubernetes.io/part-of: data-estate-platform
        tenant: acme
      annotations:
        linkerd.io/inject: enabled
    spec:
      serviceAccountName: estate-scanner
      terminationGracePeriodSeconds: 30        # drain deadline 25s + 5s buffer
      securityContext:
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: estate-scanner
      initContainers:
        - name: migrate
          image: ghcr.io/acme/data-estate/estate-scanner@sha256:9f8a3b…
          command: ["/app/migrate", "up"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: estate-scanner-db, key: url }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits: { memory: 128Mi }
      containers:
        - name: estate-scanner
          image: ghcr.io/acme/data-estate/estate-scanner@sha256:9f8a3b…
          ports:
            - name: http
              containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { memory: 256Mi }           # no CPU limit — latency-sensitive
          startupProbe:
            httpGet: { path: /startupz, port: http }
            failureThreshold: 30
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            periodSeconds: 10
            failureThreshold: 6
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 5
            failureThreshold: 2
          lifecycle:
            preStop:
              sleep: { seconds: 3 }
          envFrom:
            - configMapRef: { name: estate-scanner-env }
---
# 3. PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: estate-scanner
  namespace: tenant-acme
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: estate-scanner
```

---

## Full Worked Example — Rollout (Canary Progressive Delivery)

For services using canary progressive delivery, replace `Deployment` with `Rollout`. All other manifest objects (ServiceAccount, PDB, NetworkPolicy) are identical. The `helm-chart` template renders this when `workloadType: rollout`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: compliance-engine
  namespace: tenant-acme
  labels:
    app.kubernetes.io/name: compliance-engine
    app.kubernetes.io/part-of: data-estate-platform
    tenant: acme
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: compliance-engine
  template:
    metadata:
      labels:
        app.kubernetes.io/name: compliance-engine
      annotations:
        linkerd.io/inject: enabled
    spec:
      serviceAccountName: compliance-engine
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: compliance-engine
          image: ghcr.io/acme/data-estate/compliance-engine@sha256:4c7d2e…
          ports:
            - name: http
              containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          resources:
            requests: { cpu: 200m, memory: 256Mi }
            limits: { memory: 512Mi }
          startupProbe:
            httpGet: { path: /startupz, port: http }
            failureThreshold: 30
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            periodSeconds: 10
            failureThreshold: 6
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 5
            failureThreshold: 2
          lifecycle:
            preStop:
              sleep: { seconds: 3 }
  strategy:
    canary:
      steps:
        - setWeight: 20            # 20% of traffic to canary pods
        - pause: { duration: 5m }  # observe for 5 minutes
        - analysis:
            templates:
              - templateName: success-rate   # defined by canary-deployment skill
            args:
              - name: service-name
                value: compliance-engine
        - setWeight: 50
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: compliance-engine
        - setWeight: 100
      # Auto-rollback on analysis failure: argo-rollouts handles this natively
      # The Rollout status reflects the promotion state — visible in GitOps reconciliation
```

**Blue-green variant** (`canary:` replaced with `blueGreen:`):

```yaml
  strategy:
    blueGreen:
      activeService: compliance-engine-active
      previewService: compliance-engine-preview
      autoPromotionEnabled: false    # manual promotion gate (or set to true for automated)
      prePromotionAnalysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: compliance-engine
      postPromotionAnalysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: compliance-engine
```

Blue-green requires two `Service` objects (`compliance-engine-active` and `compliance-engine-preview`) rather than one, so the `helm-chart` template creates both when `strategy: blueGreen`.

---

## PodDisruptionBudget and Topology Spread — Worked Example

A multi-replica service needs both a PodDisruptionBudget (so voluntary disruptions — node drains, cluster upgrades — take at most one replica at a time) and a topology spread constraint (so replicas do not co-schedule onto one node and disrupt together). `minAvailable`/`maxUnavailable` must leave enough capacity for the SLO (`slo-definition`) during a rolling node upgrade.

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

---

## NetworkPolicy Worked Example — Default-Deny plus Per-Service Allow

Every tenant namespace starts closed with a `default-deny` policy selecting all pods for both Ingress and Egress; each flow is then re-opened as an explicit, reviewable allow that mirrors the Container Diagram. A new architecture arrow is a new NetworkPolicy rule in a reviewed PR.

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

---

## Output Format Template

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

## Workload Type
[Deployment | StatefulSet | DaemonSet | Job | CronJob | Rollout] — rationale from kubernetes-workload-patterns

## Rendered Objects
[Workload type] · Service · ServiceAccount · PodDisruptionBudget · NetworkPolicy · (HPA if autoscaling.enabled)
Init containers: [list with purpose of each]

## Probe Wiring
| Endpoint | Probe | periodSeconds | failureThreshold | Rationale |
[one row per probe]

## Resource Sizing
CPU request: [value] — from [go-load-test run reference]
Memory request: [value] — from [go-load-test run reference]
Memory limit: [value] — [observed peak] × 1.2 = [limit]; within 20% rule
CPU limit: omitted (latency-sensitive) | [value] (batch/background — not latency-sensitive)

## Shutdown Contract
App drain deadline: [N]s (go-service-skeleton drain timeout)
terminationGracePeriodSeconds: [N+5]s
preStop sleep: [N]s (routing propagation window)
Verification: drain + preStop ≤ terminationGracePeriodSeconds - 2s [true/false]

## Network Allows
| Direction | From/To | Port | Container Diagram arrow |
[one row per allow rule; default-deny confirmed present]

## Progressive Delivery
workloadType: [deployment | rollout]
Strategy: [none | canary with N steps | blueGreen]
AnalysisTemplate: [name] (defined by canary-deployment or blue-green-deployment skill)

## Traceability
Container Diagram element: [name]
NFR IDs: [availability NFR ref, security NFR ref]
SLO reference: [slo-definition artifact]
```
