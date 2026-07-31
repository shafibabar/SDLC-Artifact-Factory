# Argo Rollouts Cookbook — Progressive Delivery

Self-contained reference. Provides complete Rollout + AnalysisTemplate YAML for canary (Linkerd + Prometheus)
and blue-green strategies, plus wiring to this platform's existing SLO burn-rate Prometheus rules.

---

## Why Argo Rollouts

Argo Rollouts extends Kubernetes with a `Rollout` CRD that replaces `Deployment` for services needing
progressive delivery. The key difference: promotion and rollback criteria are declared as versioned Git
objects (`AnalysisTemplate`), not pipeline scripts that exist only in CI logs.

From *GitOps and Kubernetes* (Yuen et al., Ch. 10): "The `AnalysisTemplate` is versioned in Git alongside
the rollout spec; a failed analysis creates a Git-observable event (the rollout status), not just a CI
log artifact."

---

## Installation Prerequisite

Argo Rollouts is installed via its official Helm chart. Confirm the operator is running before any Rollout
CRD is applied:

```bash
kubectl get pods -n argo-rollouts
# Expected: argo-rollouts-* pod in Running state
```

If not installed, the `Rollout` CRD will be accepted (CRD exists) but no controller will reconcile it.
Argo Rollouts installation is an `opentofu-module` provisioning decision, not a per-service decision.

---

## Canary Rollout with Linkerd + Prometheus

### 1. The Rollout CRD (replaces Deployment)

```yaml
# charts/estate-scanner/templates/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: estate-scanner
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: estate-scanner
  template:
    metadata:
      labels:
        app: estate-scanner
      annotations:
        linkerd.io/inject: enabled           # Linkerd proxy injection
    spec:
      containers:
        - name: estate-scanner
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /healthz/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz/live
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 30
  strategy:
    canary:
      # Linkerd traffic split: the mesh handles weight-based routing
      # via canaryService/stableService Services
      canaryService: estate-scanner-canary    # Service pointing to canary pods
      stableService: estate-scanner-stable    # Service pointing to stable pods
      trafficRouting:
        linkerd: {}                           # Argo Rollouts Linkerd integration
      steps:
        - setWeight: 5                        # Stage 1: 5% canary
        - pause:
            duration: 15m                    # 15-minute hold for signal accumulation
        - analysis:
            templates:
              - templateName: estate-scanner-slo-gate
            args:
              - name: service
                value: estate-scanner
              - name: slot
                value: canary
        - setWeight: 25                       # Stage 2: 25% canary
        - pause:
            duration: 30m
        - analysis:
            templates:
              - templateName: estate-scanner-slo-gate
        - setWeight: 50                       # Stage 3: 50% canary
        - pause:
            duration: 30m
        - analysis:
            templates:
              - templateName: estate-scanner-slo-gate
        # Stage 4: 100% — handled by Argo Rollouts promotion to stable
      autoPromotionEnabled: false             # Require explicit promotion OR clean analysis
      # With autoPromotionEnabled: false + analysis steps, Argo Rollouts
      # auto-promotes only when all analysis runs pass. Failed analysis = rollback.
```

### 2. The AnalysisTemplate

```yaml
# charts/estate-scanner/templates/analysis-slo-gate.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: estate-scanner-slo-gate
  namespace: {{ .Values.namespace }}
spec:
  args:
    - name: service
    - name: slot
      value: canary
  metrics:
    - name: error-rate-fast-burn
      # Query against this platform's existing recording rules from alerting-rules-design.
      # The fast-burn threshold: error rate > 14.4 × error budget fraction.
      # For SLO = 99.5% availability, error budget fraction = 0.005.
      # Fast-burn threshold: 0.005 × 14.4 = 0.072 (7.2% error rate).
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            service:http_request_errors:ratio_rate5m{
              service="{{ args.service }}",
              slot="{{ args.slot }}"
            }
      successCondition: result[0] < 0.072    # Below 14.4x fast-burn threshold
      failureLimit: 0                        # Any failure triggers rollback
      interval: 2m
      count: 3                               # Must pass 3 consecutive checks

    - name: latency-regression
      # p99 canary must not exceed stable by more than 20%
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            (
              histogram_quantile(0.99, sum by (le) (
                rate(http_request_duration_seconds_bucket{
                  service="{{ args.service }}",
                  slot="{{ args.slot }}"
                }[10m])
              ))
              /
              histogram_quantile(0.99, sum by (le) (
                rate(http_request_duration_seconds_bucket{
                  service="{{ args.service }}",
                  slot="stable"
                }[10m])
              ))
            )
      successCondition: result[0] < 1.2      # Canary p99 < 120% of stable p99
      failureLimit: 0
      interval: 5m
      count: 2

    - name: error-rate-vs-baseline
      # Canary error ratio must not exceed stable by more than 1.5x
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            (
              service:http_request_errors:ratio_rate5m{
                service="{{ args.service }}", slot="{{ args.slot }}"
              }
              /
              service:http_request_errors:ratio_rate5m{
                service="{{ args.service }}", slot="stable"
              }
            )
      successCondition: result[0] < 1.5      # Canary error rate < 1.5x stable
      failureLimit: 1                        # One failure allowed (may be transient)
      interval: 5m
      count: 2
```

### 3. The Two Services (Linkerd Traffic Split Target)

```yaml
# charts/estate-scanner/templates/services.yaml
apiVersion: v1
kind: Service
metadata:
  name: estate-scanner-stable
  namespace: {{ .Values.namespace }}
spec:
  selector:
    app: estate-scanner
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: estate-scanner-canary
  namespace: {{ .Values.namespace }}
spec:
  selector:
    app: estate-scanner
  ports:
    - port: 8080
      targetPort: 8080
```

Argo Rollouts manages the pod selector labels on these two Services to route traffic to stable vs. canary pods. The Linkerd HTTPRoute (if needed explicitly) is created by the Argo Rollouts Linkerd integration automatically — the `trafficRouting: linkerd: {}` in the Rollout spec activates this.

---

## Blue-Green Rollout with Argo Rollouts

### 1. The Rollout CRD (Blue-Green Strategy)

```yaml
# charts/auth-service/templates/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: auth-service
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
      annotations:
        linkerd.io/inject: enabled
    spec:
      containers:
        - name: auth-service
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
  strategy:
    blueGreen:
      activeService: auth-service-active      # Service currently receiving traffic
      previewService: auth-service-preview    # Service pointing to the new (green) pods
      autoPromotionEnabled: false             # Require explicit promotion — never auto
      prePromotionAnalysis:
        templates:
          - templateName: auth-service-pre-promotion-gate
        args:
          - name: service
            value: auth-service
      postPromotionAnalysis:
        templates:
          - templateName: auth-service-post-promotion-gate
        args:
          - name: service
            value: auth-service
      scaleDownDelaySeconds: 3600             # Keep blue running for 1 hour post-promotion
                                              # Provides instant rollback window
      abortScaleDownDelaySeconds: 30          # If promotion aborts, scale down preview quickly
```

### 2. Pre-Promotion AnalysisTemplate

```yaml
# charts/auth-service/templates/analysis-pre-promotion.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: auth-service-pre-promotion-gate
  namespace: {{ .Values.namespace }}
spec:
  args:
    - name: service
  metrics:
    - name: preview-health-check
      # Verify the preview (green) service is responding correctly before promotion.
      # Uses a synthetic health probe rather than production traffic (preview has no
      # live traffic yet in blue-green).
      provider:
        web:
          url: "http://auth-service-preview.{{ .Values.namespace }}.svc.cluster.local:8080/healthz/ready"
          jsonPath: "{$.status}"
      successCondition: result == "ok"
      failureLimit: 0
      interval: 30s
      count: 5                               # Must pass 5 consecutive health checks

    - name: schema-migration-complete
      # Verify the contract migration completed without errors using the migration
      # job's outcome metric (published by go-migration's migrate tool).
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            auth_service_schema_migration_errors_total
      successCondition: result[0] == 0
      failureLimit: 0
      count: 1
```

### 3. Post-Promotion AnalysisTemplate

```yaml
# charts/auth-service/templates/analysis-post-promotion.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: auth-service-post-promotion-gate
  namespace: {{ .Values.namespace }}
spec:
  args:
    - name: service
  metrics:
    - name: post-promotion-error-rate
      # After promotion, the active service is green. Verify it is not burning
      # error budget faster than the SLO allows. Same fast-burn threshold as canary.
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            service:http_request_errors:ratio_rate5m{service="{{ args.service }}"}
      successCondition: result[0] < 0.072
      failureLimit: 1
      interval: 2m
      count: 5                               # 10 minutes of clean signal post-promotion
```

---

## Wiring to This Platform's Prometheus Recording Rules

The `AnalysisTemplate` queries reference recording rules that already exist from `alerting-rules-design`. No new Prometheus rules need to be created for Argo Rollouts — the same expressions that drive alerting pages drive rollout gates.

**Recording rules consumed by the cookbook templates:**

| Recording rule | Source | Used in |
|---|---|---|
| `service:http_request_errors:ratio_rate5m` | `alerting-rules-design` SLO burn-rate rules | Fast-burn and error-vs-baseline gates |
| `http_request_duration_seconds_bucket` | `opentelemetry-instrumentation` histogram export | Latency-regression gate |

**Label convention for canary slot discrimination:**
The `slot` label (`slot="canary"` / `slot="stable"`) must be emitted by the application's OpenTelemetry instrumentation or by Linkerd's per-pod metrics when the Rollout creates canary/stable pods. Argo Rollouts automatically adds `rollouts-pod-template-hash` labels — the `slot` label must either be injected via `podTemplateMetadata` in the Rollout spec or derived from the existing Rollout pod hash. Verify the label is present in Prometheus before the first rollout:

```bash
# Verify slot label exists
kubectl exec -n monitoring prometheus-0 -- \
  promtool query instant http://localhost:9090 \
  'service:http_request_errors:ratio_rate5m{service="estate-scanner"}'
# Expected output should show {slot="canary"} and {slot="stable"} series
```

---

## Operational Commands

```bash
# Check rollout status
kubectl argo rollouts get rollout estate-scanner -n tenant-acme

# Manually promote (if autoPromotionEnabled: false and analysis passed)
kubectl argo rollouts promote estate-scanner -n tenant-acme

# Abort rollout (triggers rollback to stable)
kubectl argo rollouts abort estate-scanner -n tenant-acme

# Retry after fixing the issue that caused an abort
kubectl argo rollouts retry rollout estate-scanner -n tenant-acme

# Watch rollout progress in real time
kubectl argo rollouts get rollout estate-scanner -n tenant-acme --watch

# List AnalysisRuns for a rollout
kubectl get analysisruns -n tenant-acme -l rollout=estate-scanner
```

---

## Rollout Status States

| Status | Meaning | Action |
|---|---|---|
| `Progressing` | Rollout is stepping through canary stages | Monitor analysis metrics |
| `Paused` | Rollout is waiting at a pause step | Inspect logs; promote or abort |
| `Healthy` | Rollout completed; canary promoted to stable | None |
| `Degraded` | Analysis failed; rollback complete | Investigate failed AnalysisRun |
| `Error` | Controller error (misconfigured CRD, missing Service) | Fix configuration; retry |

A `Degraded` rollout does not require manual cleanup — Argo Rollouts has already reverted the pod count and Service selectors. The failed `AnalysisRun` object remains for inspection until manually deleted or until the namespace's `AnalysisRun` TTL (configurable in Argo Rollouts controller config) expires.

---

## Per-Tenant Rollout Configuration

Under this platform's physical multi-tenancy model, each tenant has its own namespace. Rollouts in `tenant-canary` complete before the fleet wave promotes to `tenant-acme` and other tenant namespaces. The same Rollout + AnalysisTemplate manifests deploy to each tenant namespace with tenant-scoped values.

```yaml
# deploy/clusters/tenants/tenant-acme/estate-scanner-values.yaml
namespace: tenant-acme
replicaCount: 3
image:
  repository: ghcr.io/org/estate-scanner
  tag: "sha-abc1234"        # Same digest as tenant-canary — never rebuilt
```

The `cd-pipeline`'s fleet-wave PR updates the image tag in each tenant's values file. Argo CD (or Flux) reconciles the updated Rollout, which begins the canary sequence in that tenant's namespace independently.
