# Sync Primitives Decision Table — Full Worked Examples

Full standard referenced from `go-concurrency-patterns/SKILL.md`'s "The sync
Primitives" section. Self-contained — reads without the parent body already in
context. Grounded in Cox-Buday's *Concurrency in Go* (ch. 2–3, the channel-vs-mutex
heuristic) and Donovan & Kernighan's *The Go Programming Language* (ch. 9, the
`sync` package). Where this repo already has a real, correct instance of a
primitive, that instance is the worked example — not an invented one.

The governing heuristic (Cox-Buday): are you transferring *ownership* of a piece of
data between goroutines, coordinating independent pieces of logic, or signalling an
occurrence? → reach for a **channel**. Are you guarding a struct's own internal
state, in a small critical section? → reach for `sync.Mutex`/`sync.RWMutex`, or
`sync/atomic` if that state is a single field. Neither the book nor this skill
treats "prefer channels" as dogma — a `Mutex` around a small in-memory map is
routinely simpler and faster than a channel-guarded goroutine, and picking a mutex
over a channel is not "doing Go wrong."

---

## `chan` — Handing Off Ownership or Signalling

Use a channel when one goroutine is done with a piece of data and another goroutine
now owns it, or when a goroutine only needs to know *that* something happened, not
inspect shared state. The worker pool's job channel is the canonical instance:

```go
select {
case job := <-jobs:
    process(job)
case <-ctx.Done():
    return ctx.Err() // cancellation always has an escape hatch
}
```

Never use a channel to guard a struct's own internal state that only that struct's
methods touch — that is what `Mutex`/`RWMutex` are for, and a channel used this way
adds goroutine-scheduling overhead a mutex doesn't need.

---

## `sync.Mutex` — General Mutual Exclusion

Use when a small critical section of shared mutable state needs protecting and
there is no meaningful ownership transfer happening — the state lives for the life
of the guarding struct, and multiple goroutines read and write it directly.
`go-middleware`'s per-subject rate limiter is the real, in-repo instance: a
`limiterStore` holds a `map[string]*limiterEntry` that both the request path
(reading/creating an entry) and a background sweep goroutine (evicting idle
entries) touch concurrently.

```go
type limiterStore struct {
    mu       sync.Mutex
    limiters map[string]*limiterEntry
    rate     rate.Limit
    burst    int
}
```

The lock is held only long enough to read or mutate the map — never across the
`rate.Limiter`'s own token-bucket check, and never across I/O. Holding a `Mutex`
across a channel operation or an I/O call is the anti-pattern this repo forbids
everywhere: lock, touch memory, unlock.

---

## `sync.RWMutex` — Read-Heavy State, Rare Writes

Use only when reads genuinely, heavily outnumber writes and the critical section is
read-dominated — otherwise a plain `Mutex` is simpler and often faster, since an
`RWMutex`'s bookkeeping has more overhead per lock/unlock than a `Mutex`'s. The
real, in-repo instance is `health-check-design`'s `Readiness` struct: many
concurrent request-path reads of a `ready bool` flag, versus one infrequent writer
(the drain sequence flipping `ready` to `false` on shutdown).

```go
type Readiness struct {
    mu    sync.RWMutex
    ready bool
}

func (rd *Readiness) Handler(w http.ResponseWriter, r *http.Request) {
    rd.mu.RLock()
    accepting := rd.ready
    rd.mu.RUnlock()
    // ...
}
```

Every request-path read takes `RLock`, letting arbitrarily many readers proceed
concurrently; only the rare write (flipping `ready`) takes the exclusive `Lock`.
Reaching for `RWMutex` on state that is written about as often as it's read gains
nothing and costs more than a plain `Mutex`.

---

## `sync.WaitGroup` — Waiting on N Unrelated Goroutines, No Result to Collect

Use when a known set of goroutines must all finish before proceeding, and there is
no error or value to propagate — if there is, reach for `errgroup` instead, since a
bare `WaitGroup` gives no channel for errors to travel back on. The generic fan-in's
merge goroutine is the worked example already in this skill
(`references/worked-example.md`): `wg.Add(len(sources))`, one `wg.Done()` per
producer, and the goroutine that calls `wg.Wait()` is the one that closes the merged
output channel — guaranteeing the close happens exactly once, after every producer
has actually finished.

---

## `sync.Once` — Exactly-Once Lazy Initialisation

Use for state that must be built exactly once, lazily, on first use, regardless of
how many goroutines reach the initialisation point concurrently — a compiled
regexp, a parsed config, a singleton client. `Once.Do` blocks every concurrent
caller until the first call's function returns, then never runs it again:

```go
var (
    cfgOnce sync.Once
    cfg     *Config
)

func loadedConfig() *Config {
    cfgOnce.Do(func() { cfg = parseConfig() }) // runs exactly once, ever
    return cfg
}
```

Never reach for `Once` when initialisation is conditional or must be able to run
again later (a cache that can be invalidated and rebuilt) — that needs an explicit
`Mutex`-guarded rebuild, not `Once`, which by design cannot be reset.

---

## `sync/atomic` — Lock-Free Counters and Flags on a Single Word

Use for a lock-free counter or boolean flag under high contention, when the guarded
state is exactly one field — cheaper than a `Mutex` at that size, and never a
substitute for one on anything larger. Two real, in-repo instances:

- `go-event-consumer`'s liveness heartbeat keeps two independent `atomic.Int64`
  timestamps, `lastTickerPulse` and `lastLoopPulse` — updated without a lock from
  the ticker goroutine and the consume loop respectively, read without a lock by
  whatever reports liveness.
- `go-chaos-test`'s `faultyPublisher` uses `failNext atomic.Bool` to flip fault
  injection on and off from a test goroutine while the publish path reads it
  concurrently — a single boolean flag, exactly the shape `atomic` is for.

Reaching for `atomic` on a struct with several related fields that must change
together is the failure mode to avoid — that is a torn-update bug waiting to
happen; use a `Mutex` guarding the whole struct instead.

---

## `errgroup` — Parallel Stages with Cancellation and Error Propagation

Covered in full, with its own worked examples, in
`references/goroutine-lifecycle-standard.md`. The one-line placement in this table:
reach for `errgroup` whenever more than one goroutine's success must be judged
together and a failure in one should stop the others — `go-service-layer`'s
parallel query fan-out (two goroutines, ad hoc confinement, no mutex needed because
each writes only its own destination variable) is the real instance.
