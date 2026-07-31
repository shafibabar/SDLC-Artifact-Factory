# Timeout, Flakiness, and CI-Execution Standard

Full material for `SKILL.md`'s "Timeout, Flakiness & CI Execution" section.
Self-contained. Covers container-startup hardening, network-dependent-assertion
hardening, and how parallel-safe CI execution differs from a local dev run.

---

## 1. Container-Startup Retry and Bounded Timeout

A container that fails to start is almost always an environment problem (a
transient Docker daemon hiccup, an image-pull race on a cold CI runner) — not
evidence the code under test is broken. Treated as a hard failure with no retry,
it produces a false-negative CI run that a re-run fixes with no code change,
which trains engineers to distrust red builds exactly the way `go-unit-test`
warns a broken pillar does.

- **Retry the container start itself**, not the test: 3 attempts, exponential
  backoff (500ms, 1s, 2s), wrapping `postgres.Run`/`redpanda.Run` in
  `internal/test/containers.go` — never wrapping the test function, which would
  also silently retry a genuine assertion failure.
- **Bound the whole startup with a context timeout** — 30s is generous enough to
  absorb a cold image pull, tight enough that a genuinely broken Docker daemon
  fails the CI job in under a minute instead of hanging until the job's overall
  timeout kills it with no diagnostic message.

```go
func startWithRetry(ctx context.Context, start func(context.Context) (testcontainers.Container, error)) (testcontainers.Container, error) {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    var lastErr error
    for attempt, backoff := 0, 500*time.Millisecond; attempt < 3; attempt++ {
        c, err := start(ctx)
        if err == nil {
            return c, nil
        }
        lastErr = err
        select {
        case <-ctx.Done():
            return nil, fmt.Errorf("container start timed out after retries: %w", lastErr)
        case <-time.After(backoff):
        }
        backoff *= 2
    }
    return nil, fmt.Errorf("container failed to start after 3 attempts: %w", lastErr)
}
```

## 2. Network-Dependent Assertions — Poll, Never Sleep

`time.Sleep(N)` to "wait for" the outbox relay, a consumer, or any other
asynchronous effect is a standing anti-pattern for two opposite failure modes at
once: too short on a loaded CI runner (flaky failure) and too long on a fast
local run (a slow suite for no reason). The standard is a bounded poll loop —
`awaitEvent` in `repository-and-event-testing.md` §5 is the canonical shape:
poll every 50–100ms, fail with a clear message at a fixed deadline (5s is this
repo's default for in-process outbox/consumer round trips; raise it only for a
specifically slower operation, never as a blanket default). A poll-based wait is
fast when the system is fast and fails with an actionable message when it is
not — a fixed sleep is neither.

## 3. Parallel-Safe CI Container Allocation

- **Dynamic port allocation is what makes parallel container use safe at all.**
  Testcontainers assigns each container instance an OS-chosen host port rather
  than a fixed one — two packages' Postgres containers running concurrently in
  CI never collide on port 5432, because neither of them is actually bound to
  5432 on the host. This requires no manual coordination; it is the library's
  default behavior, and this repo's containers never override it with a fixed
  host-port mapping.
- **One shared Postgres + one shared Redpanda per test *binary* (package), not
  per test function** — this is `testcontainers-setup-standard.md` §2's
  container-per-package strategy restated as a CI capacity fact: a CI run with
  `go test ./... -p N` spins up at most one container pair per package running
  concurrently, not one pair per test. A CI runner sized for, say, 8 parallel
  packages needs capacity for 8 Postgres + 8 Redpanda containers at once, not
  hundreds.
- **`t.Parallel()` is safe at the test-function level once isolation is
  transaction-based** (`test-isolation-standard.md`'s default) — concurrent
  transactions against the one shared package container don't observe each
  other's uncommitted writes, so marking every table-driven integration
  subtest `t.Parallel()` is the norm, not an opt-in. It becomes **unsafe** the
  moment a test is on the real-commit exception path without tenant scoping —
  two parallel tests committing against the same tenant/rows race exactly like
  any other shared-mutable-state parallel bug.
- **`-short` skip stays the inner-loop gate.** `TestMain`'s
  `if testing.Short() { os.Exit(0) }` (`testcontainers-setup-standard.md` §3)
  means `go test -short ./...` — the fast local inner loop — never pays
  container-startup cost at all; only `go test ./...` without `-short`, which
  CI always runs, pays it.

## 4. How CI Differs from a Local Dev Run

| Aspect | Local dev | CI |
|---|---|---|
| Image cache | Usually warm (Docker Desktop keeps recently pulled images) | Often cold on a fresh runner — the first pull of a pinned tag costs real time |
| Container startup budget | The `testcontainers-setup-standard.md` §4 numbers are typically met or beaten | The same numbers should still hold; a CI-specific image-layer cache (documented as an optional CI pipeline optimization, not a requirement) closes most of the gap if it doesn't |
| Parallelism | Usually run serially or with a small `-p` while iterating | Runs at the CI runner's full package parallelism by default — this is where dynamic port allocation (§3) actually gets exercised |
| Retry value | Rarely needed — a stable local Docker daemon and warm cache mean §1's retry path rarely triggers | Where §1's retry earns its cost — transient CI infrastructure hiccups are the primary reason it exists at all |

Pinning exact image tags (`postgres:16-alpine`, not `postgres:latest`) is what
keeps both columns of this table honest: an unpinned tag can silently change
size or startup behavior between a developer's laptop and the CI runner on
different days, defeating the whole point of comparing them.
