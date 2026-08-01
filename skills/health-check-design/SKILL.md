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
version: 1.2.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, observability, health-check, liveness, readiness, kubernetes, probes]
produces: health-check-endpoints
domain: observability
status: stable
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

Readiness reflects whether the instance can serve a request *now*, which means its critical dependencies are reachable. Each check is bounded by a 2-second context timeout so a slow dependency cannot hang the probe itself. The `Readiness` struct holds a `ready` flag (toggled to false on shutdown) and a map of `CheckFunc` values. When `ready` is false the handler returns 503 with `"draining"` immediately without running dependency checks.

Dependency checks are cheap liveness pings, not deep queries:

```go
ready.AddCheck("postgres", func(ctx context.Context) error { return pool.Ping(ctx) })
ready.AddCheck("broker",   func(ctx context.Context) error { return broker.Ping(ctx) })
```

Check only **critical** dependencies — the ones without which the service genuinely cannot serve. A non-critical dependency being down should degrade a feature, not pull the whole instance from rotation. Full `Readiness` struct and `Handler` implementation: `references/go-implementation.md`.

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

## Managed Lifecycle — terminationGracePeriodSeconds

**Critical correctness rule (Kubernetes Patterns — Managed Lifecycle pattern):** The pod spec's `terminationGracePeriodSeconds` MUST be greater than or equal to the application's drain timeout. The formula is:

```
terminationGracePeriodSeconds = app_drain_timeout_seconds + 5
```

The Go server's drain timeout is the `context.WithTimeout` deadline passed to `http.Server.Shutdown` — the `cfg.ShutdownTimeout` value in the service's config. If the app drain takes 30 seconds and `terminationGracePeriodSeconds` is the Kubernetes default of 30 seconds, SIGKILL fires before the drain completes — in-flight requests are dropped. The +5 second buffer absorbs jitter between when SIGTERM arrives and when `Shutdown` begins.

**Who sets what:**
- The backend-engineer sets `cfg.ShutdownTimeout` (e.g., `30s`) in the service's Go config. This is the source value.
- The platform-engineer reads that value from `values.yaml` and sets `terminationGracePeriodSeconds = cfg.ShutdownTimeout + 5` in the pod spec.

```yaml
# In the pod spec (set by platform-engineer):
spec:
  terminationGracePeriodSeconds: 35   # = 30s drain timeout + 5s buffer
  containers:
    - name: my-service
```

Without this alignment, rolling deploys that show a clean `helm upgrade` output still drop in-flight requests.

---

## preStop Hook — Buffering Slow SIGTERM Handlers

When the application cannot detect and react to SIGTERM fast enough (e.g., goroutine scheduling delay means it takes 1–2 seconds before drain begins), add a `preStop` lifecycle hook. The kubelet runs `preStop` before sending SIGTERM, giving the application a guaranteed head start before the termination countdown begins.

```yaml
containers:
  - name: my-service
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sleep", "2"]
```

When the sleep is added, increase `terminationGracePeriodSeconds` by the same number of seconds to preserve the total drain window:

```
terminationGracePeriodSeconds = app_drain_timeout_seconds + preStop_sleep_seconds + 5
```

**When to use:** add `preStop` only when load tests or drain-time measurements confirm that in-flight requests are still being dropped on shutdown despite correct `terminationGracePeriodSeconds`. Do not add it universally — every rolling deploy pays the sleep cost during pod termination.

---

## Deploy-then-Verify (Post-Deploy Smoke Test)

The health endpoints this skill specifies serve a second role: they are the targets of the post-deploy verification gate. After every `helm upgrade` (or after Flux/Argo CD applies a new revision), run:

```bash
kubectl rollout status deployment/<name> --timeout=120s \
  && curl -f http://<service>/healthz/ready
```

If either command exits non-zero, trigger `helm rollback` (push-model CI) or a GitOps revert. A deploy that passes `helm upgrade` without this gate is not confirmed — `helm upgrade` exits 0 when the API server accepts the new spec, not when the new pods are healthy.

See `references/deploy-verification.md` for the complete verification script, GitOps (Flux/Argo CD) variant, SLO burn rate extension, and integration with `cd-pipeline`.

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
| Grace period aligned | terminationGracePeriodSeconds = drain_timeout + 5 | SIGKILL fires before drain completes |
| Post-deploy verified | rollout status + /readyz checked after every deploy | Deploy declared done without health verification |

---

## Anti-Patterns

- **Liveness checking dependencies** — the classic self-inflicted outage: the database blips, every replica's liveness fails simultaneously, and the orchestrator restart-storms a fleet that was fine.
- **One endpoint for both probes** — a single `/health` wired to both liveness and readiness forces one of them to have the wrong semantics; the probes ask different questions and get different answers.
- **Deep queries in readiness** — running `SELECT count(*) FROM data_assets` as a "health check" turns the probe into load. A `Ping` proves reachability; that is all readiness needs.
- **Unbounded checks** — a dependency check without a timeout lets one slow dependency hang the probe until the orchestrator's own timeout declares the instance dead for the wrong reason.
- **Closing the listener before going not-ready** — the load balancer keeps routing to a closed socket for one probe period; connection-refused errors on every deploy are the signature.
- **Non-critical dependencies failing readiness** — the analytics sidecar being down should degrade a feature flag, not remove the instance from rotation.
- **Caching "ready" forever** — readiness computed once at startup can never reflect a dependency that failed later; checks run per probe, cheaply.
- **terminationGracePeriodSeconds at the Kubernetes default (30s) with a 30s drain timeout** — SIGKILL fires exactly when drain would finish; the +5 buffer is always required.
- **No post-deploy smoke test** — `helm upgrade` exiting 0 means the API server accepted the new spec, not that the new pods are healthy; a failing probe for the new version does not block the Helm operation without a post-deploy gate.

---

## Output Format

Produces Go source, tests, and platform configuration:

```
internal/handlers/http/health.go          (live/ready/startup handlers, Readiness type)
internal/handlers/http/health_test.go      (ready/not-ready/dep-down/draining cases)
# values.yaml: terminationGracePeriodSeconds = cfg.ShutdownTimeout + 5
# post-deploy: rollout status + /readyz gate per references/deploy-verification.md
```

Full Go implementation: `references/go-implementation.md`
Post-deploy verification: `references/deploy-verification.md`
