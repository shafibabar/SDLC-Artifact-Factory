---
name: health-check-design
description: >
  Teaches how to design health and readiness endpoints for a Go service — the
  distinction between liveness, readiness, and startup probes, dependency health
  checks (DB, broker) with bounded timeouts, the not-ready-on-shutdown signal that
  drains traffic gracefully, avoiding cascading failure from over-eager liveness,
  and how the endpoints map to Kubernetes probes. Health checks are what let the
  platform route traffic only to healthy instances. Used by the backend-engineer
  during Implement; probes are wired by the platform-engineer.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, observability, health-check, liveness, readiness, kubernetes, probes]
---

# Health Check Design

## Purpose

Health endpoints let the orchestrator make correct routing and restart decisions: send traffic only to instances that can serve it, and restart only instances that are truly broken. Get them wrong and you cause the outages you were trying to prevent — an over-eager liveness probe restart-loops a healthy-but-busy service; a readiness probe that ignores dependencies routes traffic into a service that can't reach its database.

This skill produces the in-code endpoints and their semantics. The platform-engineer wires them to Kubernetes probe definitions with the right thresholds.

---

## Three Probes, Three Questions

| Probe | Question | Failure action | Endpoint |
|---|---|---|---|
| **Liveness** | "Is the process wedged beyond recovery?" | **Restart** the container | `/healthz` |
| **Readiness** | "Can it serve traffic *right now*?" | **Remove from the load balancer** (no restart) | `/readyz` |
| **Startup** | "Has it finished starting?" | Hold off liveness/readiness until done | `/startupz` (or readiness with a longer initial delay) |

The distinction is the whole point: **readiness failure must not restart the process.** A service that has lost its database is not ready (pull it from rotation) but is not dead (restarting won't bring the database back, and restart-looping makes recovery worse).

---

## Liveness — Keep It Trivial

Liveness must answer only "is this process fundamentally stuck?" It must **not** check dependencies. If liveness checked the database, a database blip would restart every replica simultaneously — turning a recoverable dependency outage into a full self-inflicted outage.

```go
// Liveness: the process is running and the HTTP server responds. Nothing else.
func (h *Health) Live(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK) // a deadlocked process can't reach here; that's the only signal needed
}
```

Keep it cheap, dependency-free, and fast. The only thing it proves is that the event loop is turning.

---

## Readiness — Check Dependencies, with Timeouts

Readiness reflects whether the instance can serve a request *now*, which means its critical dependencies are reachable. Each check is bounded by a short timeout so a slow dependency can't hang the probe itself.

```go
type Readiness struct {
    mu     sync.RWMutex
    ready  bool
    checks map[string]CheckFunc
}
type CheckFunc func(context.Context) error

func (rd *Readiness) Handler(w http.ResponseWriter, r *http.Request) {
    rd.mu.RLock()
    accepting := rd.ready
    rd.mu.RUnlock()
    if !accepting {
        writeJSON(w, http.StatusServiceUnavailable, status{Status: "draining"}) // shutting down
        return
    }

    ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second) // bound the whole probe
    defer cancel()

    results := make(map[string]string, len(rd.checks))
    healthy := true
    for name, check := range rd.checks {
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
    writeJSON(w, code, status{Status: st, Checks: results})
}
```

Dependency checks are cheap liveness pings, not deep queries:

```go
ready.AddCheck("postgres", func(ctx context.Context) error { return pool.Ping(ctx) })
ready.AddCheck("broker",   func(ctx context.Context) error { return broker.Ping(ctx) })
```

Check only **critical** dependencies — the ones without which the service genuinely cannot serve. A non-critical dependency being down should degrade a feature, not pull the whole instance from rotation.

---

## Not-Ready on Shutdown — Graceful Drain

The most valuable readiness behaviour: flip to **not-ready the instant shutdown begins**, before the server stops accepting connections. The load balancer sees not-ready, stops sending new requests, and in-flight requests drain — zero dropped requests on deploy. (Wired into the lifecycle — see `go-service-skeleton`.)

```go
// On SIGTERM: mark not-ready FIRST, then let in-flight requests finish, then shut down.
g.Go(func() error {
    <-gctx.Done()
    ready.SetNotReady()              // LB stops routing here
    time.Sleep(cfg.DrainDelay)       // give the LB a beat to notice before the server closes
    return nil
})
```

This ordering — not-ready → drain → close — is why rolling deploys don't drop requests.

---

## Startup Probe — Protect Slow Starts

If a service needs time to warm up (run migrations, prime a cache, connect pools), a startup probe tells Kubernetes "don't apply liveness/readiness yet." Without it, a slow start trips the liveness probe and the orchestrator restart-loops a service that was simply starting.

The startup endpoint reports OK once initialisation has completed; until then, liveness is suppressed by the orchestrator.

---

## Mapping to Kubernetes (handed to platform-engineer)

The endpoints are designed to map cleanly to probe definitions the platform-engineer authors:

| Endpoint | Probe | Typical config |
|---|---|---|
| `/healthz` | livenessProbe | high failureThreshold; never tied to dependencies |
| `/readyz` | readinessProbe | short period; reflects dependency + draining state |
| `/startupz` | startupProbe | generous failureThreshold × period to cover worst-case start |

Health routes are mounted **outside** the authenticated middleware group (see `go-middleware`) — probes carry no JWT.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Liveness ≠ readiness | Liveness dependency-free; readiness checks deps | Liveness checking the DB (restart storms) |
| Readiness no-restart | Readiness failure pulls from LB, never restarts | Readiness wired to liveness semantics |
| Bounded checks | Every dependency check has a timeout | A probe that can hang on a slow dependency |
| Drain on shutdown | Not-ready set first; in-flight drains | Process closes before LB stops routing |
| Critical deps only | Only must-have dependencies fail readiness | Non-critical dep downing the whole instance |
| Startup protected | Slow start covered by a startup probe | Slow start restart-looping on liveness |
| Probes unauthenticated | Health routes outside the auth group | Probes requiring a token |

---

## Anti-Patterns

- **Liveness checking dependencies** — the classic self-inflicted outage: the database blips, every replica's liveness fails simultaneously, and the orchestrator restart-storms a fleet that was fine.
- **One endpoint for both probes** — a single `/health` wired to both liveness and readiness forces one of them to have the wrong semantics; the probes ask different questions and get different answers.
- **Deep queries in readiness** — running `SELECT count(*) FROM data_assets` as a "health check" turns the probe into load. A `Ping` proves reachability; that is all readiness needs.
- **Unbounded checks** — a dependency check without a timeout lets one slow dependency hang the probe until the orchestrator's own timeout declares the instance dead for the wrong reason.
- **Closing the listener before going not-ready** — the load balancer keeps routing to a closed socket for one probe period; connection-refused errors on every deploy are the signature.
- **Non-critical dependencies failing readiness** — the analytics sidecar being down should degrade a feature flag, not remove the instance from rotation.
- **Caching "ready" forever** — readiness computed once at startup can never reflect a dependency that failed later; checks run per probe, cheaply.

---

## Output Format

Produces Go source plus tests for each probe state:

```
internal/handlers/http/health.go          (live/ready/startup handlers, Readiness type)
internal/handlers/http/health_test.go      (ready/not-ready/dep-down/draining cases)
```
