# Kubernetes Logging Pipeline — Reference

This reference covers the full lifecycle of a structured log line on Kubernetes: from
the service writing to stdout, through kubelet capture and rotation, to Fluent Bit
forwarding, and finally into Loki where it is indexed and queryable. Read this when
implementing or configuring any part of the logging stack for a service deployed on
Kubernetes.

---

## Pipeline Overview

```
Service (Go, JSON to stdout)
  └─► kubelet (captures, rotates /var/log/containers/*.log)
        └─► Fluent Bit DaemonSet (reads log files, parses JSON, enriches with K8s metadata)
              └─► Loki (stores by label set; indexed by stream selectors)
                    └─► Grafana (queries via LogQL; correlates with Prometheus/Tempo)
```

This pipeline is **zero-configuration from the service's perspective**. The service writes
JSON to stdout. Everything else — capture, rotation, shipping, indexing — is handled by
platform components that are already present on every cluster node.

---

## Why Stdout-Only Is Mandatory on Kubernetes

Writing logs to a file instead of stdout is a compliance violation. Three independent
reasons enforce this rule:

**1. Sidecar tax.** A file-based logging service requires a sidecar log shipper container
in every pod. Each sidecar adds:
- A container to every pod definition (Deployment, StatefulSet, DaemonSet)
- CPU and memory requests multiplied by every replica
- A shared `emptyDir` volume between the app container and the sidecar
- Additional failure modes: the sidecar can crash independently of the app

On a 100-replica service, a 50m CPU / 64Mi memory sidecar adds 5 CPU cores and 6.4 GiB
of memory requests to the cluster — a real scheduling cost that reduces the capacity
available to actual application workloads.

**2. Pod eviction data loss.** If the sidecar uses a shared volume (`emptyDir`), that
volume is ephemeral. When the kubelet evicts a pod (OOM, node pressure, preemption), the
volume is destroyed. Any buffered, unshipped log lines in that volume are permanently
lost. A pod that crashes under load is exactly the pod whose logs you most need to see —
and they vanish with the pod.

**3. Invisible logs.** The Fluent Bit DaemonSet on every node reads from
`/var/log/containers/`, which is where the kubelet writes stdout. A service that writes to
a file inside its container filesystem does not appear in `/var/log/containers/` and is
therefore **invisible to the platform's log aggregator**. Its logs do not reach Loki,
cannot be queried by Grafana, and are not retained by the platform's log retention policy.
The logs exist only until the container restarts, at which point they are gone.

A service that writes logs to a file instead of stdout is non-compliant: its logs are
invisible to the platform's log aggregator.

---

## Kubernetes Log Path Convention

The kubelet writes container stdout/stderr to files at:

```
/var/log/containers/<pod-name>_<namespace>_<container-name>-<container-id>.log
```

Example:
```
/var/log/containers/data-classifier-7d6f9c-xk2mq_data-estate_classifier-a3b1c2d4.log
```

Fluent Bit reads this path convention via a wildcard tail input. The kubelet also manages
log rotation automatically — by default 10 files × 10 MiB per container — so neither the
service nor Fluent Bit needs to implement rotation logic.

---

## Fluent Bit DaemonSet Configuration

Fluent Bit runs as a DaemonSet (one pod per node) so it can read every container's log
files directly from the node filesystem. The following is the minimal, correct
configuration for this stack's JSON-structured logs forwarding to Loki.

### values.yaml snippet (Fluent Bit Helm chart)

```yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*_<namespace>_*.log
        # Use the wildcard form in the actual cluster; restrict by namespace in the
        # Helm values override if multi-tenancy requires namespace isolation.
        Multiline.Parser  docker, cri
        Tag               kube.<var.kubernetes.pod_name>.<var.kubernetes.namespace_name>.<var.kubernetes.container_name>
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        # Because the service writes JSON to stdout, Merge_Log:On parses the "log" field
        # as JSON and merges its keys into the top-level record — so trace_id, span_id,
        # tenant_id, etc. become top-level Loki label candidates, not buried in a JSON blob.
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On
        Labels              On
        Annotations         Off

  outputs: |
    [OUTPUT]
        Name            loki
        Match           kube.*
        Host            loki.monitoring.svc.cluster.local
        Port            3100
        Labels          job=fluentbit,pod=$kubernetes['pod_name'],namespace=$kubernetes['namespace_name'],service=$kubernetes['labels']['app'],env=$kubernetes['labels']['env'],tenant=$kubernetes['labels']['tenant_id']
        # pod, namespace, service (from the app label), env, and tenant_id (from the pod
        # label) are promoted to Loki stream selectors — this drives LogQL queries:
        #   {namespace="data-estate", service="classifier", env="production"}
        #   | json | trace_id="4bf92f..."
        Remove_Keys     kubernetes,stream
        Line_Format     json
```

### Key configuration decisions

| Setting | Value | Reason |
|---|---|---|
| `Merge_Log On` | Enabled | Service writes JSON; this expands it into top-level fields |
| `Labels` | pod, namespace, service, env, tenant | These are the LogQL stream selectors; keep cardinality bounded |
| `Annotations Off` | Disabled | Annotations are arbitrary strings; unlimited cardinality crashes Loki |
| `Line_Format json` | json | Loki stores the full structured record, not just the message string |
| `Mem_Buf_Limit 50MB` | 50 MiB | Backpressure cap; prevents Fluent Bit from OOMing when Loki is slow |

---

## Loki Label Design

Loki indexes on **stream labels** (low-cardinality metadata like pod, namespace, service,
env, tenant) and does **not** index on log content fields like `trace_id` or `event_id`.
High-cardinality fields (UUIDs, request IDs) are stored in the log line body and queried
with LogQL's `| json` pipe.

Correct query pattern:
```logql
{namespace="data-estate", service="classifier", env="production"}
| json
| trace_id = "4bf92f3a1c7e5b09"
```

This query first narrows by stream (fast, index-backed), then parses JSON and filters by
`trace_id` (full-scan of the matched stream). The combination is fast because the stream
is small (bounded by namespace + service + env + tenant) and the JSON parse is done on
the already-reduced set.

Anti-pattern — never make `trace_id` a Loki label:
```yaml
# WRONG — one label value per request = unbounded cardinality = Loki OOM
Labels: trace_id=$record['trace_id']
```

---

## LOG_LEVEL Configuration via Helm Values

Log level must not be baked into the container image. It is injected as an environment
variable from `values.yaml` so it can be overridden per environment without a rebuild.

### In the service (Go):

```go
func levelFromEnv() slog.Level {
    switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
    case "debug":
        return slog.LevelDebug
    case "warn", "warning":
        return slog.LevelWarn
    case "error":
        return slog.LevelError
    default:
        return slog.LevelInfo // safe default if env var is absent or unrecognised
    }
}

func InitLogging(env string) *slog.Logger {
    level := levelFromEnv()
    opts := &slog.HandlerOptions{Level: level}
    var handler slog.Handler
    if env == "production" || env == "staging" {
        handler = slog.NewJSONHandler(os.Stdout, opts)
    } else {
        handler = slog.NewTextHandler(os.Stdout, opts)
    }
    return slog.New(&traceHandler{Handler: handler})
}
```

### In values.yaml (Helm chart):

```yaml
# values.yaml — production defaults
env:
  LOG_LEVEL: "info"
  APP_ENV: "production"
```

```yaml
# values-kind-local.yaml — local development override
env:
  LOG_LEVEL: "debug"
  APP_ENV: "kind-local"
```

### In the Deployment template:

```yaml
env:
  - name: LOG_LEVEL
    value: {{ .Values.env.LOG_LEVEL | quote }}
  - name: APP_ENV
    value: {{ .Values.env.APP_ENV | quote }}
```

Default levels:
- **production**: `info` — Info and above; Debug suppressed to avoid log volume costs
- **staging**: `info` — Same as production; debug verbosity is not the purpose of staging
- **kind-local**: `debug` — Full debug output; developer iteration on local cluster

Changing log level requires only a `helm upgrade` (or a values-file change in GitOps),
not an image rebuild. This enables debug-level escalation in a live environment without
a deployment cycle.

---

## Full Go traceHandler Implementation

The `traceHandler` wraps any `slog.Handler` to inject the active OTel span's `TraceID`
and `SpanID` into every log record. This is the implementation that ships in
`internal/infrastructure/telemetry/logging.go`.

```go
package telemetry

import (
    "context"
    "log/slog"
    "os"
    "strings"

    "go.opentelemetry.io/otel/trace"
)

// traceHandler wraps a slog.Handler and injects trace_id + span_id from the
// active OTel span on every Handle call. It is the mandatory wrapper for all
// slog instances in this project.
type traceHandler struct{ slog.Handler }

func (h *traceHandler) Handle(ctx context.Context, r slog.Record) error {
    if sc := trace.SpanContextFromContext(ctx); sc.IsValid() {
        r.AddAttrs(
            slog.String("trace_id", sc.TraceID().String()),
            slog.String("span_id", sc.SpanID().String()),
        )
    }
    return h.Handler.Handle(ctx, r)
}

// WithAttrs MUST re-wrap so derived loggers (slog.With(...)) continue to inject
// trace ids. The embedded handler's WithAttrs returns the INNER handler — if we
// do not re-wrap here, a logger created via slog.With("tenant_id", t) silently
// stops injecting trace correlation. This is the canonical slog-wrapper bug.
func (h *traceHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
    return &traceHandler{Handler: h.Handler.WithAttrs(attrs)}
}

// WithGroup — same re-wrap requirement as WithAttrs.
func (h *traceHandler) WithGroup(name string) slog.Handler {
    return &traceHandler{Handler: h.Handler.WithGroup(name)}
}

func levelFromEnv() slog.Level {
    switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
    case "debug":
        return slog.LevelDebug
    case "warn", "warning":
        return slog.LevelWarn
    case "error":
        return slog.LevelError
    default:
        return slog.LevelInfo
    }
}

// InitLogging creates the production-grade logger: JSON in production/staging,
// text locally; LOG_LEVEL from env var; trace correlation on every line.
// Call once at service startup and pass the returned logger via dependency
// injection — do not use slog.SetDefault in library code.
func InitLogging(env string) *slog.Logger {
    level := levelFromEnv()
    opts := &slog.HandlerOptions{Level: level}
    var handler slog.Handler
    if env == "production" || env == "staging" {
        handler = slog.NewJSONHandler(os.Stdout, opts)
    } else {
        handler = slog.NewTextHandler(os.Stdout, opts)
    }
    logger := slog.New(&traceHandler{Handler: handler})
    slog.SetDefault(logger) // convenience: allows package-level slog.InfoContext calls
    return logger
}
```

### Testing trace correlation

```go
// internal/infrastructure/telemetry/logging_test.go
func TestTraceHandlerInjectsIDs(t *testing.T) {
    var buf bytes.Buffer
    handler := slog.NewJSONHandler(&buf, nil)
    logger := slog.New(&traceHandler{Handler: handler})

    // Create a real OTel span so SpanContextFromContext returns a valid context.
    tp := trace.NewNoopTracerProvider()
    ctx, span := tp.Tracer("test").Start(context.Background(), "test-span")
    defer span.End()

    logger.InfoContext(ctx, "test event", slog.String("key", "value"))

    var rec map[string]string
    if err := json.Unmarshal(buf.Bytes(), &rec); err != nil {
        t.Fatal(err)
    }
    if rec["trace_id"] == "" {
        t.Error("trace_id must be present on every log line")
    }
    if rec["span_id"] == "" {
        t.Error("span_id must be present on every log line")
    }
}

func TestWithAttrsDerivedLoggerStillInjectsTraceIDs(t *testing.T) {
    var buf bytes.Buffer
    handler := slog.NewJSONHandler(&buf, nil)
    base := slog.New(&traceHandler{Handler: handler})

    // Derived logger via slog.With — this is the regression test for the
    // slog-wrapper bug where WithAttrs returns the inner handler.
    derived := base.With(slog.String("tenant_id", "t-123"))

    tp := trace.NewNoopTracerProvider()
    ctx, span := tp.Tracer("test").Start(context.Background(), "op")
    defer span.End()

    derived.InfoContext(ctx, "derived logger event")

    var rec map[string]string
    json.Unmarshal(buf.Bytes(), &rec)
    if rec["trace_id"] == "" {
        t.Error("derived logger lost trace_id — WithAttrs re-wrap is broken")
    }
}
```

---

## Checklist: Service Logging Compliance

- [ ] Service writes all output to stdout (no log files, no syslog calls)
- [ ] JSON handler used in production and staging (`slog.NewJSONHandler(os.Stdout, opts)`)
- [ ] Text handler used in kind-local (`slog.NewTextHandler(os.Stdout, opts)`)
- [ ] `traceHandler` wraps the base handler (trace_id + span_id on every line)
- [ ] `WithAttrs` and `WithGroup` re-wrap the outer handler (slog-wrapper bug absent)
- [ ] `LOG_LEVEL` read from environment variable, not hardcoded
- [ ] values.yaml sets `LOG_LEVEL: "info"` for production, `LOG_LEVEL: "debug"` for kind-local
- [ ] All logging uses `InfoContext`/`ErrorContext`/`WarnContext` (never bare `slog.Info`)
- [ ] Consistent snake_case keys used across all services
- [ ] No secrets or PII in any log attribute (verified by test asserting redaction)
- [ ] Fluent Bit DaemonSet configured with `Merge_Log: On` so JSON fields are top-level in Loki
- [ ] Loki labels: pod, namespace, service, env, tenant — no UUIDs as labels
