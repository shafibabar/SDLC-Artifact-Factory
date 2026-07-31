# Deadlock, Livelock, and Starvation — Incident-Response Runbook

Full runbook referenced from `go-concurrency-patterns/SKILL.md`'s "Deadlock,
Livelock, and Starvation" section. Self-contained — reads without the parent body
already in context. Grounded in Cox-Buday's *Concurrency in Go* (the
deadlock/livelock/starvation taxonomy and the tooling-blind-spot caveat) and this
repo's own `go-performance-optimization` (pprof) and `go-chaos-test`
(hypothesis-driven experiments).

Three distinct failure modes, each different from a goroutine **leak** (an
unbounded goroutine with no exit — see the Goroutine Lifecycle Standard) and a
**data race** (concurrent, unsynchronized memory access, which `go test -race`
exists specifically to catch):

- **Deadlock** — two or more goroutines each wait on a resource the other holds;
  neither can proceed. A **full deadlock** (every goroutine in the process blocked
  simultaneously) is the one case Go's runtime notices and crashes on. A **partial
  deadlock** (some goroutines stuck, the rest of the process running fine) is the
  common real-world shape and the runtime says nothing about it.
- **Livelock** — goroutines are actively running and scheduled, repeatedly reacting
  to each other (backing off, retrying, yielding), but making no real progress —
  CPU stays busy, throughput stays near zero.
- **Starvation** — a goroutine that *could* proceed is perpetually denied the
  resource it needs (an unfair lock, a greedy sibling that never backs off), while
  the rest of the system keeps running normally.

**The critical caveat: no automated tool in this toolchain catches a partial
deadlock or a livelock.** Go's runtime deadlock detector
(`fatal error: all goroutines are asleep - deadlock!`) only fires when *every*
goroutine in the process is simultaneously blocked — it has nothing to trigger on
for a partial deadlock or a livelock (a livelocked goroutine is actively scheduled,
not blocked, so there is nothing for a blocking-detector to notice). `go test -race`
proves the absence of *data races* only — a completely different problem from a
goroutine that is simply stuck or spinning uselessly. Both failure shapes are found
only by behavioral and load testing, and by reading a goroutine dump correctly.

---

## Step 1: What Crashed, If Anything?

If the process itself crashed with `fatal error: all goroutines are asleep -
deadlock!`, this is a **full deadlock** and the runtime has already done the
diagnosis for you: the crash dump lists every goroutine and its blocked stack
trace. Read every listed goroutine's stack — the cycle of "who's waiting on whom"
is visible directly in the dump; skip straight to Step 3's stack-trace
interpretation.

If the process is still running but one code path has stopped making progress —
this is the common case, and it is invisible to any crash, since nothing crashed.
Proceed to Step 2.

---

## Step 2: Check Goroutine Count First

Before anything else, sample the live goroutine profile:

```
curl http://internal-admin-host:PORT/debug/pprof/goroutine?debug=1   # human-readable, grouped stacks
curl http://internal-admin-host:PORT/debug/pprof/goroutine?debug=2   # full stack dump, every goroutine individually
```

(`net/http/pprof` on a separate, internal-only admin port — never the public API
port; see `go-performance-optimization`.) Take the count and shape as the first
diagnostic signal:

| Signal | Read as |
|---|---|
| Goroutine count climbing without bound over time | A **leak**, not a deadlock — see the Goroutine Lifecycle Standard, not this runbook |
| Goroutine count flat, elevated above steady state, and CPU is **idle** | **Partial deadlock** — proceed to Step 3 |
| Goroutine count flat, elevated above steady state, and CPU is **pegged** | **Livelock** — proceed to Step 4 |
| Goroutine count and CPU both look normal, but one specific request class or worker never completes | **Starvation** localized to a subset — proceed to Step 5 |

---

## Step 3: Interpreting a Stuck Goroutine's Stack Trace

With `?debug=2`, every goroutine's stack is printed individually. The first line of
each stuck goroutine's dump names *why* it's blocked — read this literally, it
names the exact primitive:

| Stack shows | Means | What to check next |
|---|---|---|
| `goroutine stuck in chan receive` (or `chan send`) | Blocked on an unbuffered or full/empty channel operation | Is there a `select` with a `ctx.Done()` case at this exact call site? If not, that's the missing escape hatch — see the Leak Prevention Checklist. If there is one, the context itself was never cancelled — a separate bug upstream |
| `semacquire` | Blocked acquiring a `sync.Mutex`, `sync.RWMutex`, or `sync.WaitGroup` — all three use the runtime's semaphore internally, so they all show this same label | Find who currently holds the lock (the other stuck goroutine's stack, in a full dump, will show it mid-critical-section) — that pair is the deadlock cycle |
| `select` (no further detail, no case fires) | Blocked in a `select` with no ready case | Confirm a `ctx.Done()` case exists in the `select` at all — if it does and still isn't firing, the parent context was never actually cancelled, which is the real bug, not the `select` itself |
| `IO wait` | Blocked on a network read/write or syscall, not on any Go synchronization primitive | This is not deadlock — it's a slow or hung downstream dependency. Check the downstream's health, not this repo's concurrency code |

For a **partial deadlock**, you are looking for two (or more) goroutines whose
stacks are each `semacquire` on a lock the other one's stack shows it currently
holding — the classic lock-ordering cycle. `go-chaos-test`'s partial-deadlock
experiment deliberately induces exactly this shape (two workers acquiring two
shared locks in opposite order under contention) to prove the fix holds, rather
than waiting to observe it once in production.

---

## Step 4: Confirming Livelock

A livelock never shows a `semacquire` or `chan receive` stack — every goroutine
involved is `runnable` or actively executing, because livelocked goroutines are, by
definition, not blocked. The tell is in the **CPU profile**, not the goroutine
dump: pull a CPU profile (`go tool pprof -http=:0 cpu.out`, `go-performance-optimization`)
during the stall and look for a hot, repeating loop in retry/backoff or
lock-yielding code — goroutines spinning through the same small set of functions
over and over with no forward progress. Flat goroutine count plus pegged CPU plus a
hot loop in contention-handling code is the full livelock signature.

---

## Step 5: Confirming Starvation

Starvation looks almost normal in a single snapshot — the starved goroutine is
`runnable`, not blocked, which is exactly what makes it easy to miss. The diagnostic
is **differential**: take two or three goroutine dumps a few seconds apart and diff
which stacks actually advanced. A starved goroutine's stack trace stays in the same
`semacquire`/`runnable` state across every dump while its sibling goroutines'
stacks visibly progress between dumps — it is never being scheduled the lock or
resource it's waiting on, even though nothing is technically deadlocked.

---

## Step 6: Reproduce Deliberately, Don't Just Infer From One Snapshot

A single production incident, diagnosed once from one goroutine dump, is a
hypothesis — not a proof, and not something the fix can be validated against
later. Confirm the diagnosis, and prove a fix holds, with a hypothesis-driven chaos
experiment (`go-chaos-test`'s partial-deadlock/livelock row): state the steady
state, inject the specific contention pattern suspected (two goroutines racing for
two shared locks in opposite order; a retry loop under sustained contention), and
watch for the same goroutine-count/CPU signature under controlled conditions. This
is the only place in the toolchain that turns "we think we saw a partial deadlock
once" into "we proved this fix prevents it," since neither `-race` nor the runtime
detector will ever confirm it directly.

---

## Runbook Summary Table

| Symptom | Goroutine count | CPU | Stack trace label | Diagnosis |
|---|---|---|---|---|
| Process crashed | n/a | n/a | Dump lists every blocked goroutine | Full deadlock — runtime already told you |
| One path stalled, process alive | Flat, elevated | Idle | `semacquire` / `chan receive` in a cycle | Partial deadlock |
| One path stalled, process alive | Flat, elevated | Pegged | `runnable`, hot loop in retry/backoff code | Livelock |
| One goroutine never progresses, siblings do | Normal | Normal | `runnable`/`semacquire`, unchanged across repeated dumps | Starvation |
| Count keeps climbing | Unbounded growth | Varies | New goroutines accumulating, not stuck | Leak — not this runbook, see Goroutine Lifecycle Standard |
