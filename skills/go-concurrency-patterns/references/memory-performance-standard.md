# Memory and Performance Standard for Concurrent Code

Full standard referenced from `go-concurrency-patterns/SKILL.md`'s "Memory and
Performance for Concurrent Code" section. Self-contained — reads without the parent
body already in context. This is the concurrency-specific companion to
`go-performance-optimization`'s general allocation/escape-analysis standard: that
skill covers allocation and GC pressure broadly; this section covers the three
places *concurrency itself* creates a memory or throughput cost that a purely
sequential program never pays.

---

## Goroutine Cost Is Small but Not Zero

A goroutine's stack starts at roughly 2KB and grows on demand (doubling as needed,
shrinking back under GC pressure), versus roughly one to several megabytes for an
OS thread's fixed stack — this is the reason Go programs can casually run tens of
thousands of goroutines where an equivalent thread-per-unit design would exhaust
memory long before that. But "cheap" is not "free": an **unbounded
goroutine-per-request or goroutine-per-item pattern under high concurrency is a
real memory risk**, not a theoretical one — a burst of ten thousand concurrent
requests, each spawning its own unbounded goroutine, allocates ten thousand stacks
plus scheduler bookkeeping plus whatever each goroutine's closure captures.

The captured-state cost compounds the stack cost: any variable a goroutine's
closure references that escapes to the heap (`go-domain-model` and
`go-performance-optimization` already establish escape analysis for this repo)
stays live for as long as the goroutine holding a reference to it is alive. A
goroutine that never exits — a leak, per the Owned/Bounded/Joined standard — is
therefore very often a memory leak of everything it captured, not merely "one more
scheduled thing the runtime has to track." This is the concrete, quantifiable
reason the Goroutine Lifecycle Standard's **Bounded** property is non-negotiable:
an unbounded spawn is an unbounded memory commitment, however small each individual
goroutine looks in isolation.

---

## Worker-Pool Sizing: CPU-Bound vs I/O-Bound

Picking a worker count "by feel" is the anti-pattern; the count should be derived
from what the workers actually spend their time doing:

| Workload shape | Starting formula | Why |
|---|---|---|
| **CPU-bound** — the work itself is the bottleneck (parsing, hashing, compression) | `workers == runtime.GOMAXPROCS(0)` | Beyond the number of logical CPUs actually available, additional workers add context-switch and scheduler overhead with no throughput gain — the CPUs are already saturated |
| **I/O-bound** — workers spend most of their time blocked waiting on a network call, a downstream service, or a disk | `workers ≈ GOMAXPROCS × (1 + wait/service)` — more workers than CPUs, scaled by how much of each unit of work is spent blocked versus actually computing | While one worker waits on I/O, its CPU is idle and another worker can use it; the ratio of wait-time to service-time (Little's-Law-derived) estimates how many workers keep the CPUs busy despite the blocking |

Both formulas are **starting points, not final answers** — the actual right number
depends on downstream capacity (a worker pool sized for CPU headroom that
overwhelms a downstream database is not actually correctly sized) and must be
validated with a real saturation sweep, not trusted as arithmetic alone: see
`go-load-test`'s USE-method throughput sweep and `go-performance-test`'s
benchmark-gated regression tracking. A worker count is a tuning parameter to be
measured under realistic load, not a constant to set once and forget.

---

## Channel Buffer Sizing: the Tradeoff, Precisely

Both channel shapes cost something different — the choice is a deliberate tradeoff,
not a stylistic preference:

- **Unbuffered.** A send blocks until a receiver is ready — this *is* the
  backpressure signal: the moment a consumer falls behind, the producer feels it
  immediately, at the next send. Correct default for coordination, handoff, and
  signalling, where immediate backpressure is exactly the property wanted.
- **Buffered, size N.** A send blocks only once the buffer is full, so a producer
  can run up to N items ahead of a stalled consumer before feeling any
  backpressure at all. This has two concrete, opposite-signed costs against the
  unbuffered case:
  1. **A bounded but real memory allocation up front** — `make(chan T, N)`
     allocates room for N elements of `T` immediately, regardless of whether the
     buffer is ever filled.
  2. **A delayed backpressure signal** — a producer racing N items ahead of a
     genuinely stuck consumer produces no observable slowdown until the buffer
     fills, which can mask a stalled consumer for however long it takes to fill
     N slots, exactly the same blind spot the Liveness Heartbeat pattern exists to
     close for a stalled-but-scheduled goroutine (`go-event-consumer`).

`N` is therefore a deliberate, stated bound sized to the burst it needs to smooth
— never "make it big" as an ad hoc safety margin. `make(chan T, 100000)` is not a
generous buffer; it is a hidden memory allocation and a backpressure signal
delayed by up to 100000 items, which is the anti-pattern this skill's Anti-Patterns
section names directly.

---

## Quick Self-Check

| Question | If the answer is wrong |
|---|---|
| Is the goroutine count for this workload bounded by something concrete (a fixed pool, `SetLimit`, a known fan-out length)? | Add a bound — an unbounded spawn is an unbounded memory commitment |
| Is the worker count derived from CPU-bound or I/O-bound reasoning, then validated by a load test? | Re-derive it from the formula above and confirm with `go-load-test`, don't guess |
| Is every channel buffer size a stated, deliberate number tied to a specific burst it needs to absorb? | Replace an arbitrary large buffer with the smallest size that smooths the actual burst |
