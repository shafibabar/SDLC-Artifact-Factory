# Health Check Go Implementation

Full implementation reference for `internal/handlers/http/health.go`. This file is
self-contained — it can be read without `SKILL.md` in context.

---

## File Layout

```
internal/handlers/http/health.go       # Readiness type, all three handlers
internal/handlers/http/health_test.go  # table-driven tests for all probe states
```

---

## Readiness Type

The `Readiness` struct holds the draining flag and the registered dependency checks. It
is safe for concurrent use — the `mu` guards `ready` and `checks` together.

```go
package http

import (
    "context"
    "encoding/json"
    "net/http"
    "sync"
    "time"
)

// CheckFunc is a dependency health probe. It receives a context with a deadline
// shared across all checks for the current probe invocation.
type CheckFunc func(context.Context) error

// Readiness is the /readyz handler. Create one per server; call SetNotReady on
// SIGTERM before closing the listener.
type Readiness struct {
    mu     sync.RWMutex
    ready  bool
    checks map[string]CheckFunc
}

// NewReadiness returns a Readiness that starts in the ready state.
func NewReadiness() *Readiness {
    return &Readiness{
        ready:  true,
        checks: make(map[string]CheckFunc),
    }
}

// AddCheck registers a named dependency check. Call before the server starts.
func (rd *Readiness) AddCheck(name string, fn CheckFunc) {
    rd.mu.Lock()
    defer rd.mu.Unlock()
    rd.checks[name] = fn
}

// SetNotReady flips the ready flag to false. Call this as the first action on
// SIGTERM so the load balancer stops routing before the listener closes.
func (rd *Readiness) SetNotReady() {
    rd.mu.Lock()
    defer rd.mu.Unlock()
    rd.ready = false
}
```

---

## Handler Implementation

```go
type probeStatus struct {
    Status string            `json:"status"`
    Checks map[string]string `json:"checks,omitempty"`
}

func writeJSON(w http.ResponseWriter, code int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    _ = json.NewEncoder(w).Encode(v)
}

// Handler is the /readyz HTTP handler.
func (rd *Readiness) Handler(w http.ResponseWriter, r *http.Request) {
    rd.mu.RLock()
    accepting := rd.ready
    snapshot  := make(map[string]CheckFunc, len(rd.checks))
    for k, v := range rd.checks {
        snapshot[k] = v
    }
    rd.mu.RUnlock()

    // Drain signal: return 503 immediately without running dependency checks.
    if !accepting {
        writeJSON(w, http.StatusServiceUnavailable, probeStatus{Status: "draining"})
        return
    }

    // Bound the total time for all dependency checks together.
    ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
    defer cancel()

    results := make(map[string]string, len(snapshot))
    healthy  := true
    for name, check := range snapshot {
        if err := check(ctx); err != nil {
            results[name] = "down"
            healthy = false
        } else {
            results[name] = "up"
        }
    }

    code, st := http.StatusOK, "ready"
    if !healthy {
        code, st = http.StatusServiceUnavailable, "not_ready"
    }
    writeJSON(w, code, probeStatus{Status: st, Checks: results})
}
```

---

## Liveness and Startup Handlers

```go
// Health is the liveness handler.
type Health struct{}

// Live is the /healthz HTTP handler. Dependency-free: the only signal it
// provides is that the HTTP event loop is turning. Kubernetes restarts the
// container if this endpoint stops responding.
func (h *Health) Live(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, probeStatus{Status: "ok"})
}

// Startup is the /startupz HTTP handler. Set started=true once all
// initialisation (migrations, pool warm-up) has completed; until then
// Kubernetes suppresses liveness and readiness probes.
type Startup struct {
    mu      sync.RWMutex
    started bool
}

func (s *Startup) SetStarted() {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.started = true
}

func (s *Startup) Handler(w http.ResponseWriter, r *http.Request) {
    s.mu.RLock()
    done := s.started
    s.mu.RUnlock()
    if done {
        writeJSON(w, http.StatusOK, probeStatus{Status: "started"})
    } else {
        writeJSON(w, http.StatusServiceUnavailable, probeStatus{Status: "starting"})
    }
}
```

---

## Route Registration

Health routes must be mounted **outside** the authenticated middleware group so
Kubernetes probes (which carry no JWT) are never rejected. Using `chi`:

```go
r := chi.NewRouter()

// Authenticated application routes
r.Group(func(r chi.Router) {
    r.Use(middleware.JWTVerifier(...))
    r.Mount("/api", apiRouter())
})

// Health routes — no authentication
health   := &Health{}
startup  := &Startup{}
readiness := NewReadiness()
readiness.AddCheck("postgres", func(ctx context.Context) error { return pool.Ping(ctx) })
readiness.AddCheck("broker",   func(ctx context.Context) error { return broker.Ping(ctx) })

r.Get("/healthz",  health.Live)
r.Get("/readyz",   readiness.Handler)
r.Get("/startupz", startup.Handler)
```

---

## Graceful Shutdown Wiring

The readiness `SetNotReady` call must be the **first** action on SIGTERM, before
the listener stops accepting connections. Using `errgroup` and a context cancelled
by signal:

```go
// In main or cmd/server:
g, gctx := errgroup.WithContext(ctx)

// 1. Drain signal — runs first when context is cancelled (SIGTERM received).
g.Go(func() error {
    <-gctx.Done()
    readiness.SetNotReady()          // LB stops routing here
    time.Sleep(cfg.DrainDelay)       // e.g., 5s — give LB a beat to notice
    return nil
})

// 2. HTTP server — shuts down after drain window expires.
g.Go(func() error {
    <-gctx.Done()
    shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
    defer cancel()
    return server.Shutdown(shutdownCtx)
})

// 3. Background workers (consumer, scheduler) — also cancel on context.
g.Go(func() error {
    return consumer.Run(gctx)
})

if err := g.Wait(); err != nil && !errors.Is(err, context.Canceled) {
    log.Error("server stopped with error", "err", err)
}
```

`cfg.ShutdownTimeout` (the `http.Server.Shutdown` deadline) is the value the
platform-engineer uses to set `terminationGracePeriodSeconds`:

```
terminationGracePeriodSeconds = cfg.ShutdownTimeout_seconds + 5
```

---

## Test Cases

```go
// internal/handlers/http/health_test.go
package http_test

import (
    "net/http"
    "net/http/httptest"
    "testing"
    "context"
    "errors"
    "strings"
)

func TestLive_AlwaysOK(t *testing.T) {
    h := &Health{}
    w := httptest.NewRecorder()
    h.Live(w, httptest.NewRequest(http.MethodGet, "/healthz", nil))
    if w.Code != http.StatusOK {
        t.Errorf("expected 200, got %d", w.Code)
    }
}

func TestReadiness_Ready(t *testing.T) {
    rd := NewReadiness()
    rd.AddCheck("db", func(_ context.Context) error { return nil })
    w := httptest.NewRecorder()
    rd.Handler(w, httptest.NewRequest(http.MethodGet, "/readyz", nil))
    if w.Code != http.StatusOK {
        t.Errorf("expected 200, got %d", w.Code)
    }
    if !strings.Contains(w.Body.String(), `"ready"`) {
        t.Errorf("expected ready status, got: %s", w.Body.String())
    }
}

func TestReadiness_DependencyDown(t *testing.T) {
    rd := NewReadiness()
    rd.AddCheck("db", func(_ context.Context) error { return errors.New("connection refused") })
    w := httptest.NewRecorder()
    rd.Handler(w, httptest.NewRequest(http.MethodGet, "/readyz", nil))
    if w.Code != http.StatusServiceUnavailable {
        t.Errorf("expected 503, got %d", w.Code)
    }
    if !strings.Contains(w.Body.String(), `"not_ready"`) {
        t.Errorf("expected not_ready status, got: %s", w.Body.String())
    }
}

func TestReadiness_Draining(t *testing.T) {
    rd := NewReadiness()
    rd.SetNotReady()
    w := httptest.NewRecorder()
    rd.Handler(w, httptest.NewRequest(http.MethodGet, "/readyz", nil))
    if w.Code != http.StatusServiceUnavailable {
        t.Errorf("expected 503, got %d", w.Code)
    }
    if !strings.Contains(w.Body.String(), `"draining"`) {
        t.Errorf("expected draining status, got: %s", w.Body.String())
    }
}

func TestStartup_NotStartedYet(t *testing.T) {
    s := &Startup{}
    w := httptest.NewRecorder()
    s.Handler(w, httptest.NewRequest(http.MethodGet, "/startupz", nil))
    if w.Code != http.StatusServiceUnavailable {
        t.Errorf("expected 503 before SetStarted, got %d", w.Code)
    }
}

func TestStartup_AfterSetStarted(t *testing.T) {
    s := &Startup{}
    s.SetStarted()
    w := httptest.NewRecorder()
    s.Handler(w, httptest.NewRequest(http.MethodGet, "/startupz", nil))
    if w.Code != http.StatusOK {
        t.Errorf("expected 200 after SetStarted, got %d", w.Code)
    }
}
```

---

## Package and Import Notes

- Place all types in `internal/handlers/http/` alongside the other HTTP handlers.
- Import `"golang.org/x/sync/errgroup"` for the graceful-shutdown wiring above.
- `pool.Ping(ctx)` is `*pgxpool.Pool.Ping` from `github.com/jackc/pgx/v5/pgxpool`.
- `broker.Ping(ctx)` is an interface method on your broker client, wrapping a lightweight admin or connection check.
