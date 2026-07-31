# 12-Factor Kubernetes Compliance — Go Service Reference

**Self-contained:** This file is usable without `SKILL.md` in context.  
**Source:** Arundel & Domingus, *Cloud Native DevOps with Kubernetes*, Ch. 4; Wiggins, *The Twelve-Factor App* (heroku.com/12factor).  
**Purpose:** Each 12-factor principle that constitutes the Kubernetes scheduling contract for a Go service — what it means, what compliant Go code looks like, what non-compliant code looks like, which Kubernetes primitive it maps to, and how to detect violations mechanically.

The 12-factor methodology originated at Heroku but is treated by Arundel & Domingus not as a style guide but as the **compliance surface between an application and the Kubernetes scheduler**. A non-compliant service may run correctly in development and still fail in production when the scheduler evicts a pod, reschedules it to a different node, or scales it to N replicas.

---

## Factor 1 — Config from Environment Variables Only

### What it means

All configuration that varies between environments (development, staging, production) — service addresses, database URLs, feature flags, log levels, timeouts, API keys — must be injected as environment variables at deploy time. Nothing that varies between environments may be baked into the container image.

### Compliant Go pattern

```go
// cmd/server/main.go — all configuration sourced from env at startup

import "os"

type Config struct {
    DatabaseURL     string
    RedpandaBroker  string
    LogLevel        string
    HTTPPort        string
    JWTSecret       string
    EnableFeatureX  bool
}

func configFromEnv() Config {
    return Config{
        DatabaseURL:    mustEnv("DATABASE_URL"),
        RedpandaBroker: mustEnv("REDPANDA_BROKER"),
        LogLevel:       getEnvOrDefault("LOG_LEVEL", "info"),
        HTTPPort:       getEnvOrDefault("HTTP_PORT", "8080"),
        JWTSecret:      mustEnv("JWT_SECRET"),
        EnableFeatureX: os.Getenv("FEATURE_X_ENABLED") == "true",
    }
}

func mustEnv(key string) string {
    v := os.Getenv(key)
    if v == "" {
        log.Fatalf("required environment variable %q is not set", key)
    }
    return v
}

func getEnvOrDefault(key, defaultValue string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return defaultValue
}
```

The `mustEnv` pattern fails loudly at startup (not silently at the first request) — a non-configured service crashes immediately with a clear message, not intermittently under load.

### Non-compliant pattern (violation)

```go
// VIOLATION: reads a config file baked into the image
cfg, err := os.ReadFile("/etc/myservice/config.yaml")
// or
viper.SetConfigFile("./config/config.yaml")
viper.ReadInConfig()
```

Reading a `config.yaml` at startup from inside the image is the canonical violation. The image now carries environment-specific values; swapping dev-for-prod requires rebuilding the image, not a config change.

### Kubernetes wiring

```yaml
# ConfigMap for non-sensitive values
apiVersion: v1
kind: ConfigMap
metadata:
  name: classification-service-config
data:
  REDPANDA_BROKER: "redpanda.messaging.svc.cluster.local:9092"
  HTTP_PORT: "8080"
  LOG_LEVEL: "info"
---
# Secret for sensitive values
apiVersion: v1
kind: Secret
metadata:
  name: classification-service-secrets
type: Opaque
stringData:
  DATABASE_URL: "postgres://app:$(PASSWORD)@postgres.data.svc.cluster.local:5432/classification"
  JWT_SECRET: "$(JWT_SECRET_VALUE)"
---
# Deployment references both
spec:
  containers:
  - name: classification-service
    envFrom:
    - configMapRef:
        name: classification-service-config
    - secretRef:
        name: classification-service-secrets
```

### Detection

```bash
# Find config file reads that may indicate baked-in config
grep -rn "os\.ReadFile\|ioutil\.ReadFile\|os\.Open\|viper\.\|yaml\.Unmarshal" \
  cmd/ internal/ | grep -v "_test.go" | grep -v "migrations/"

# Confirm all config values trace to os.Getenv or envconfig
grep -n "os\.Getenv\|envconfig\|env\.Parse" cmd/server/main.go
```

---

## Factor 2 — Backing Services as Attached Resources

### What it means

Every external service the application depends on — the PostgreSQL database, the Redpanda broker, the Redis cache — is an **attached resource** identified by a URL injected as an environment variable. The application treats all backing services as external: there is no code difference between a local dev database and the production database. Swapping them is a configuration change, not a code change.

### Compliant Go pattern

```go
// internal/infrastructure/postgres/pool.go

func NewPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
    pool, err := pgxpool.New(ctx, databaseURL)
    if err != nil {
        return nil, fmt.Errorf("postgres: connect: %w", err)
    }
    if err := pool.Ping(ctx); err != nil {
        return nil, fmt.Errorf("postgres: ping: %w", err)
    }
    return pool, nil
}
```

`databaseURL` is passed in from `main.go`'s `configFromEnv()` — the infrastructure layer never reads env vars directly. The URL format is the same whether it points at a local `kind` cluster's postgres pod or a production RDS instance.

### Non-compliant pattern (violation)

```go
// VIOLATION: hardcoded backing service address
const dbHost = "postgres.internal:5432"
db, _ := pgxpool.New(ctx, "postgres://app:secret@"+dbHost+"/mydb")

// VIOLATION: service-specific logic distinguishing environments
if os.Getenv("ENV") == "production" {
    dbURL = "postgres://prod-host:5432/proddb"
} else {
    dbURL = "postgres://localhost:5432/devdb"
}
```

The second form is subtler but equally non-compliant: the application now knows it runs in multiple environments and contains branching logic for each. The compliant form is one env var; the deploy pipeline sets it appropriately per environment.

### Kubernetes wiring

Inside a Kubernetes cluster, backing service addresses follow the DNS convention:

```
<service-name>.<namespace>.svc.cluster.local:<port>
```

So a service named `postgres` in namespace `data` is reachable at `postgres.data.svc.cluster.local:5432`. This DNS name is stable — it does not change when pods are rescheduled. The connection string `postgres://app:$(PW)@postgres.data.svc.cluster.local:5432/classification` is injected via the `Secret` described in Factor 1.

### Detection

```bash
# Find hardcoded host/port strings in non-test Go source
grep -rn '"[a-z-]*\.[a-z]*:[0-9]\{4,5\}"\|localhost:[0-9]' \
  internal/ cmd/ | grep -v "_test.go"
```

---

## Factor 3 — Logs as Event Streams (stdout only)

### What it means

The application writes all log output to `stdout`. It writes nothing to files, nothing to named pipes, nothing to a syslog socket. The Kubernetes logging infrastructure — kubelet log rotation, DaemonSet agent (Fluent Bit), log aggregator (Loki or Elasticsearch) — captures `stdout` automatically from every container on every node. A service that writes to a file is invisible to this pipeline.

### The Kubernetes logging pipeline

```
[Go process] → stdout
    ↓
[kubelet] — captures stdout per container, rotates files on the node
    ↓
[Fluent Bit DaemonSet] — one agent per node, tails kubelet-managed files
    ↓
[Loki / Elasticsearch] — central log store, queryable by Grafana/Kibana
```

If the application writes to `/var/log/app.log`, Fluent Bit never sees it — it tails the kubelet-managed paths, not arbitrary paths the container creates. The service becomes invisible to the log aggregator.

### Compliant Go pattern

```go
// internal/infrastructure/telemetry/logger.go
// Using slog (Go 1.21+) — structured JSON to stdout

import (
    "log/slog"
    "os"
)

func NewLogger(level string) *slog.Logger {
    var l slog.Level
    _ = l.UnmarshalText([]byte(level))
    return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: l,
    }))
}
```

`os.Stdout` is the only permitted destination. The JSON format (not plain text) is required by `structured-logging-design` so the DaemonSet agent can parse fields without regex.

### Non-compliant pattern (violation)

```go
// VIOLATION: opens a file for log output
f, err := os.OpenFile("/var/log/app.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
log.SetOutput(f)

// VIOLATION: uses a logging library configured to write to a file
logger, _ := zap.NewProduction()
// zap's production config writes to stderr+stdout by default but check for
// WriteSyncer redirects to file paths in any custom zap.Config
```

### Detection

```bash
# Find log output redirected to file handles
grep -rn 'log\.SetOutput\|os\.Create\|os\.OpenFile\|bufio\.NewWriter' \
  internal/ cmd/ | grep -v "_test.go"

# Confirm slog/zap/zerolog is writing to os.Stdout (not os.Stderr or a file)
grep -rn 'os\.Stdout\|os\.Stderr' internal/infrastructure/telemetry/
# Should see os.Stdout only; os.Stderr for errors is permitted but inconsistent
# with a pipeline that routes stdout to the aggregator — prefer stdout for all levels.
```

---

## Factor 4 — No Local Disk State

### What it means

A Kubernetes pod's local filesystem is ephemeral. When a pod is evicted (node pressure), crashes (OOM), or is rescheduled (node drain, rolling update), its local filesystem is discarded. Any data written to a local path that must survive a pod restart is lost.

This is not hypothetical: the Kubernetes scheduler evicts pods under memory pressure without warning; rolling updates terminate pods before the replacement is ready; a node drain for maintenance kills all pods on that node. A service that stores anything important locally is non-compliant.

### Compliant data destinations

| Data type | Compliant destination | Kubernetes primitive |
|---|---|---|
| Relational data | PostgreSQL (external) | `Service` DNS to the postgres pod/cluster |
| Events / streams | Redpanda (external) | `Service` DNS to the Redpanda broker |
| Binary blobs / files | Object storage (S3/MinIO) or mounted PV | `PersistentVolumeClaim` |
| Shared session state | Redis (external) or PostgreSQL | `Service` DNS |
| Temporary scratch space | In-memory (OS tmpfs) only if ephemeral | — |

### Non-compliant pattern (violation)

```go
// VIOLATION: writes uploaded file to local filesystem
func (h *UploadHandler) Handle(w http.ResponseWriter, r *http.Request) {
    f, _ := os.Create("/tmp/uploads/" + filename)
    io.Copy(f, r.Body)
    // This file is lost on pod eviction.
}

// VIOLATION: caches computed state to a local file
func (svc *ClassificationService) warmCache() {
    data, _ := json.Marshal(svc.computeExpensiveResult())
    os.WriteFile("/var/cache/classification.json", data, 0644)
    // Lost on reschedule.
}
```

### Compliant pattern

```go
// Compliant: upload goes to object storage via the infrastructure layer
func (h *UploadHandler) Handle(w http.ResponseWriter, r *http.Request) {
    objectKey := uuid.New().String() + "-" + filename
    if err := h.objectStore.Put(r.Context(), objectKey, r.Body); err != nil {
        // objectStore is an interface in domain/ports.go backed by S3/MinIO
        http.Error(w, "upload failed", http.StatusInternalServerError)
        return
    }
    // Return the object key; caller retrieves via the same infrastructure
}
```

The `objectStore` port is declared in `internal/domain/ports.go`; the MinIO/S3 implementation is in `internal/infrastructure/objectstorage/`. This is the same Dependency Rule and port ownership from `SKILL.md` applied to the no-local-state requirement.

### Detection

```bash
# Find writes to /tmp or /var paths (not test fixtures)
grep -rn 'os\.Create\|os\.WriteFile\|ioutil\.WriteFile' \
  internal/ cmd/ | grep -v "_test.go" | grep -v "migrations/"

# Audit /tmp usage — ephemeral scratch use is permitted, persistent is not
grep -rn '"/tmp/' internal/ cmd/ | grep -v "_test.go"
```

---

## Factor 5 — Stateless Processes

### What it means

The application can run as N identical replicas. Any replica can handle any request. There is no per-process in-memory state that must be shared between replicas or that must persist between requests to the same replica. Sessions, caches, and computed state that must be consistent across replicas live in an external store.

This is the factor that enables Kubernetes horizontal scaling (`replicas: N`, Horizontal Pod Autoscaler) and zero-downtime rolling updates (old replicas serve traffic until new replicas are ready — request routing is arbitrary).

### Non-compliant pattern (violation)

```go
// VIOLATION: in-process session store
var sessions = map[string]Session{} // global, per-process

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
    sessionID := uuid.New().String()
    sessions[sessionID] = Session{UserID: userID, ExpiresAt: time.Now().Add(24*time.Hour)}
    // A subsequent request routed to a different replica has no sessions map entry.
    http.SetCookie(w, &http.Cookie{Name: "session", Value: sessionID})
}
```

With two replicas, 50% of subsequent requests will fail to find the session.

### Compliant pattern

```go
// Compliant: session state in PostgreSQL (or Redis)
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
    sessionID := uuid.New().String()
    if err := h.sessionStore.Create(r.Context(), sessionID, Session{
        UserID:    userID,
        ExpiresAt: time.Now().Add(24*time.Hour),
    }); err != nil {
        http.Error(w, "session creation failed", http.StatusInternalServerError)
        return
    }
    http.SetCookie(w, &http.Cookie{Name: "session", Value: sessionID})
}
```

`sessionStore` is a port in `internal/domain/ports.go`; its implementation reads/writes to PostgreSQL. Any replica that receives the next request reads the same PostgreSQL row.

### In-process caching — the correct rule

Read-through caches that hold non-authoritative copies of data from an external store are permitted:

```go
// Permitted: an in-process cache backed by an external store.
// On pod restart: the cache is cold, the service falls back to PostgreSQL.
// Under N replicas: each replica has its own cache; cache hits are independent.
// No consistency problem because the source of truth is always PostgreSQL.
type ClassificationCache struct {
    mu    sync.RWMutex
    store map[uuid.UUID]*domain.DataAsset
    repo  domain.DataAssetRepository // the external source of truth
}
```

The rule is not "no in-process memory" but "no in-process state that would produce different results for different replicas, or state that must not be lost on pod restart."

### Kubernetes deployment configuration

A stateless service is deployed as a `Deployment` (not a `StatefulSet`). The Horizontal Pod Autoscaler scales it based on CPU, memory, or custom metrics:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: classification-service
spec:
  replicas: 3                         # 3 identical, interchangeable replicas
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0               # zero-downtime: new pod ready before old pod terminates
  template:
    spec:
      containers:
      - name: classification-service
        # No hostPath volumes; no emptyDir used for persistent data
        # (emptyDir is fine for build caches/tmp in init containers, not for app data)
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: classification-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: classification-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Detection

```bash
# Find package-level maps or slices that could hold shared mutable state
grep -rn '^var [A-Za-z]* = map\|^var [A-Za-z]* = \[\]' \
  internal/ | grep -v "_test.go"

# Find sync.Mutex protecting a map (potential in-process shared state)
grep -rn 'sync\.Mutex\|sync\.RWMutex' internal/ | grep -v "_test.go"
# Each hit should be reviewed: is this an in-process cache with an external
# source of truth (permitted), or primary state that would be lost on pod restart (violation)?
```

---

## Summary Compliance Table

| Factor | Go artifact | Kubernetes primitive | Verification command |
|---|---|---|---|
| Config from env | `configFromEnv()` in `main.go` using `os.Getenv` | `ConfigMap`/`Secret` `envFrom` | `grep -rn "os.ReadFile" cmd/ internal/` |
| Backing services | Infrastructure URLs passed as constructor args from `main.go` | Service DNS name as the env var value | `grep -rn '"[a-z-]*\.[a-z]*:[0-9]"' internal/` |
| Logs as streams | `slog.NewJSONHandler(os.Stdout, ...)` | kubelet + Fluent Bit DaemonSet | `grep -rn "os.Create\|log.SetOutput" internal/` |
| No local state | All writes go through domain ports to external stores | `PersistentVolumeClaim` or external service | `grep -rn 'os.WriteFile\|"/tmp/' internal/` |
| Stateless processes | No package-level mutable maps holding primary state | `Deployment` with `replicas: N` | `grep -rn '^var.*= map' internal/` — review each hit |
