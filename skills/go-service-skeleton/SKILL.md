---
name: go-service-skeleton
description: >
  Teaches how to build the service composition root (cmd/server/main.go) —
  wiring dependencies, the exact six-stage startup order (config, logger,
  telemetry, dependencies, readiness, serve) and why that order is fixed,
  reverse-ordered shutdown with a concrete per-stage timeout budget under the
  Kubernetes termination grace period, the signal.NotifyContext signal-handling
  standard (which signals, why, and why not others), the root context every
  goroutine descends from, the readiness/liveness lifecycle contract with
  health-check-design, and complete http.Server timeout configuration
  (ReadTimeout/WriteTimeout/IdleTimeout alongside ReadHeaderTimeout). This is
  the deterministic-lifecycle backbone the blueprint demands: no orphaned
  goroutines, no request accepted before readiness, no shutdown that outruns
  the pod's grace period. Full worked startup sequence in
  references/composition-root-startup-sequence.md; full shutdown, signal, and
  health-check lifecycle standard in
  references/shutdown-and-health-standard.md. Used by the backend-engineer
  during Implement.
version: 2.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, main, lifecycle, graceful-shutdown, context, composition-root, signal-handling, readiness]
produces: go-composition-root
domain: backend
status: stable
related: [go-concurrency-patterns, go-error-handling, health-check-design, go-event-consumer, kubernetes-manifest]
---

# Go Service Skeleton

## Purpose

The composition root (`cmd/server/main.go`) is the only place that knows the concrete world: which database, which broker, which logger. It wires the layers together, starts them in a fixed, deliberate order, and — critically — shuts them down in a bounded, reverse order before Kubernetes escalates to `SIGKILL`. Every goroutine in the process descends from the root context created here, so one `Ctrl-C` or one `SIGTERM` propagates cancellation everywhere and the process exits with no leaks and no dropped in-flight work.

This is the blueprint's "deterministic lifecycle, bounded lifetime, explicit exit mechanism" applied at the top level, and the one place ordering itself — not any single line of code — is the artifact being reviewed.

---

## The Root Context

```go
func main() {
    if err := run(); err != nil {
        slog.Error("fatal", "err", err)
        os.Exit(1)
    }
}
```

`run()` returns an error instead of calling `log.Fatal` inside helpers — this keeps every `defer` running (so shutdown actually executes) and keeps `main` a single, testable funnel. `os.Exit` is called in exactly one place, in `main`, never inside `run()` or anything it calls. Every error returned out of a stage is wrapped with `fmt.Errorf("...: %w", err)` naming that stage's operation — the general wrapping, sentinel-vs-typed, and boundary-translation standard belongs to `go-error-handling`; this skill only supplies the stage name each wrap should carry (`"loading config: %w"`, `"connecting postgres: %w"`, …).

---

## Ordered Startup: Six Fixed Stages

**Config → Logger → Telemetry → Dependencies → Readiness → Serve — in that exact order, never reordered.** Each stage depends on the output of the one before it, which is why the order is fixed rather than a style preference: config parameterizes everything after it; the logger must exist before anything else needs to be observable; telemetry must exist before dependency construction so a slow or failing pool connect is itself traced; dependencies must be proven constructible before their health checks are registered against them; readiness must be registered before the listener opens, because the listener opening is the mechanical guarantee that nothing is served before the process has something legitimate to serve. Full rationale per stage and the complete worked code: `references/composition-root-startup-sequence.md`.

Each stage's own dependency call is bound to a short connect timeout via `context.WithTimeout`, derived from the root context — never left to block forever, and never sharing the root context's own much longer lifetime.

---

## Signal Handling Standard

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()
```

Exactly two signals: `os.Interrupt` for local `Ctrl-C`, `syscall.SIGTERM` because that is what Kubernetes sends before `SIGKILL`. `SIGKILL` itself is never handled — it can't be — every budget below exists so it is never the signal that actually stops the process. `SIGHUP`/`SIGQUIT` are deliberately not intercepted (no live config reload; `SIGQUIT`'s stack-dump default stays available for debugging a wedged process). `defer stop()` unregisters the relay so a second signal after a hung shutdown reverts to the OS default instead of being silently absorbed forever. Full rationale: `references/shutdown-and-health-standard.md`.

---

## Shutdown Ordering and the Timeout Budget

Shutdown is startup in reverse (Serve → Readiness → Dependencies), and it is bounded: **mark not-ready first, drain in-flight work next, close the pool, flush telemetry last** — each with a budget that sums to less than Kubernetes' `terminationGracePeriodSeconds` (30s), leaving `kubernetes-manifest`'s established 3s `preStop` hook and this skill's 25s HTTP-drain deadline (below `go-event-consumer`'s own 20s consumer drain, which runs concurrently, not sequentially) their full share, with pool close and a *bounded* telemetry flush fit into what's left. Full per-stage table with the exact arithmetic: `references/shutdown-and-health-standard.md`.

```go
g.Go(func() error {
    <-gctx.Done()
    ready.SetNotReady()                                          // FIRST — before any drain step
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
    defer cancel()
    return srv.Shutdown(shutdownCtx)                              // drains in-flight requests
})
```

Long-lived components (HTTP server, event consumer, outbox relay) are supervised together in one `errgroup` tied to the root context — if any one fails, the group cancels the rest, so shutdown is coordinated rather than orphaned. This is an application of `go-concurrency-patterns`' general goroutine-lifecycle rule (every goroutine has an owner and an explicit exit) at the process's top level; this skill adds only what's specific to the composition root — the exact stage order and the shutdown timeout budget — not a second copy of that general discipline. Full errgroup wiring, worker roster, and the readiness-registration code that precedes it: `references/composition-root-startup-sequence.md` and `references/shutdown-and-health-standard.md`.

---

## Readiness vs Liveness — the Lifecycle Contract

Liveness answers "is the process fundamentally stuck" and must never depend on anything external — checking a dependency there turns one Postgres blip into a fleet-wide restart storm. Readiness answers "can this instance serve traffic right now" and must check critical dependencies with a bounded timeout, flipping not-ready the instant shutdown begins so the load balancer drains before the process stops accepting connections. The full probe design, handler code, and Kubernetes probe mapping belong to `health-check-design` — this skill owns only the ordering contract: checks are registered after dependencies are proven constructible (Stage 5, never earlier) and not-ready is set before any drain step (shutdown order 1, never later). Full contract: `references/shutdown-and-health-standard.md`.

---

## Configuration Loading

Config comes from environment for non-secret values and from Vault Agent files for secrets (never secrets in env — see security `secrets-management`). Loading is fail-fast: a missing required value aborts startup with every missing/invalid field listed at once, not just the first.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Six-stage order held | Config→Logger→Telemetry→Dependencies→Readiness→Serve, unreordered | Any stage constructed before its dependency, e.g. readiness registered before the pool exists | Read `main.go` top to bottom against `references/composition-root-startup-sequence.md`'s table |
| One exit point | `os.Exit` only in `main`; `run()` returns errors | `log.Fatal` scattered through wiring | `grep -rn "log.Fatal\|os.Exit" --include=*.go internal/ cmd/server/main.go` — no hits outside `main`'s own `if err := run(); err != nil` block |
| Exact signal set | `os.Interrupt` + `syscall.SIGTERM` only, with `defer stop()` | Missing `SIGTERM`, or a hung shutdown with no `stop()` escape | Read the `signal.NotifyContext` call against "Signal Handling Standard" |
| Shutdown budget under grace period | Sum of every stage's budget < `terminationGracePeriodSeconds` | Any single stage using an unbounded `context.Background()` (e.g. telemetry flush) | Read every deferred shutdown call for a bound; sum against `kubernetes-manifest`'s grace period |
| No goroutine leak on shutdown | `runtime.NumGoroutine()` returns to baseline (± small tolerance) after `run()` returns | Count grows after cancellation | `TestRun_NoGoroutineLeakOnShutdown` — `references/shutdown-and-health-standard.md` |
| Readiness gated | Checks registered only after dependencies verified; not-ready set before drain | Checks registered before Stage 4 completes, or not-ready set after drain begins | Read Stage 5's position relative to Stage 4 and Order 1's position relative to Order 2 in the shutdown table |
| Liveness dependency-free | `/healthz` never calls a dependency | A dependency check reachable from the liveness path | `health-check-design`'s Quality Criteria |
| Pool sized deliberately | `MaxConns`/`MinConns`/lifetimes set from capacity math | Default pool settings shipped unexamined | Read pool config against `references/composition-root-startup-sequence.md`'s sizing rule |
| Complete server timeouts | `ReadTimeout`/`WriteTimeout`/`IdleTimeout` set alongside `ReadHeaderTimeout` | Only `ReadHeaderTimeout` set | Read the `http.Server{}` literal for all four fields |
| Race-free under load | `go test -race ./...` clean | Any data race in composition-root-owned state | `go-makefile`'s `make ci` |

---

## Anti-Patterns

- **`log.Fatal` in helpers** — kills the process mid-wiring, skipping every `defer`: no HTTP drain, no pool close, no telemetry flush. Errors bubble to `run()`; `os.Exit` lives in `main` alone.
- **Reordering the six stages** — registering readiness before dependencies are proven, or opening the listener before readiness is registered, defeats the mechanical guarantee this skill's whole ordering exists to provide. There is no "usually fine" variant of this reorder.
- **Un-supervised `go func()` components** — a consumer started with a bare `go` outside the errgroup keeps running (or dies silently) while the rest of the process shuts down.
- **An unbounded shutdown defer** — `shutdownTel(context.Background())` with no timeout lets one wedged collector consume the entire remaining shutdown margin and blow through the grace period. Every deferred shutdown call gets its own bound.
- **Shutdown budget ≥ pod grace period** — a 30s drain against a 30s grace period means Kubernetes `SIGKILL`s mid-drain; the sum of every stage's budget must leave margin, not equal the ceiling.
- **Closing the pool before components stop** — `pool.Close()` placed anywhere other than after `g.Wait()` yanks connections out from under an in-flight transaction.
- **Constructing dependencies inside layers** — a repository creating its own pool bypasses the composition root and makes lifecycle untrackable. All wiring happens in `main`.
- **Handling `SIGKILL`, or not handling `SIGTERM`** — the former is impossible (the kernel doesn't ask); the latter means the platform's only graceful-stop signal falls through to a hard stop every single deploy.
- **A readiness check with side effects** — a check that writes, or runs a business query instead of a reachability ping, turns a health probe into load and turns probe frequency into an accidental rate limiter.

---

## Output Format

`cmd/server/main.go` and `internal/config/config.go`, built exactly to the standard above — not a file listing to fill in freely:

- `main.go`'s `run()` follows the six-stage order verbatim, each stage's boundary visible as a comment (`// Stage 1: Config`, etc.) so a reviewer can check ordering without re-deriving it.
- Every deferred cleanup call is bounded by an explicit `context.WithTimeout`, sized per the shutdown budget table — never `context.Background()` alone.
- The shutdown goroutine sets not-ready before calling `srv.Shutdown`, in that order, in the same function.
- `config.go`'s `Load()` aggregates every missing/invalid field into one returned error, never returns on the first failure.
- A `TestRun_NoGoroutineLeakOnShutdown` test exists alongside `main.go` (or a testable `runTestable` it wraps), run in the same CI job as `go test -race ./...`.

Full worked startup sequence: `references/composition-root-startup-sequence.md`. Full shutdown, signal-handling, and health-check lifecycle standard: `references/shutdown-and-health-standard.md`.
