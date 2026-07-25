# Testing Standard: Writing a Test That Reliably Triggers a Race

Full standard referenced from `go-concurrency-patterns/SKILL.md`'s "Testing: Race
Detector Mandatory" section. Self-contained — reads without the parent body already
in context. `go-makefile` already makes `-race` non-negotiable, repo-wide, for
every `test` and `cover` target — this file is about the narrower, easy-to-miss
problem beneath that mandate: `-race` only catches a race that the scheduler
actually interleaves *during that specific run*, and a real, live bug can still
pass a hundred clean `-race` runs by luck before the hundred-and-first catches it.

---

## Why "It Passed `-race`" Is Not Proof of Absence

`-race` instruments memory accesses and flags a conflict only when it actually
observes two goroutines touching the same memory without synchronization *during
the run it's watching*. If a bug requires two goroutines to be executing
particular lines at nearly the same instant, and the scheduler happens not to
interleave them that way on a given run — because one goroutine finishes before
the other starts, or the racy window is narrow — the race is real, exploitable in
production, and completely invisible to that run of `-race`. Relying on incidental
scheduler timing to eventually expose a suspected race is gambling with a flaky
test, not verifying correctness.

---

## The Weak Approach: Hope and Repetition

A common but weak pattern loops many iterations and hopes the scheduler eventually
interleaves badly:

```go
// WEAK — relies on incidental scheduler timing, not a forced interleaving
func TestCounter_WeakRaceAttempt(t *testing.T) {
    c := &Counter{}
    var wg sync.WaitGroup
    for range 1000 {
        wg.Add(2)
        go func() { defer wg.Done(); c.Increment() }()
        go func() { defer wg.Done(); c.Increment() }()
        wg.Wait()
    }
}
```

This *might* trigger `-race` on an unsynchronized `Counter.Increment`, eventually,
on some machine, on some run — but a fast enough increment and a slow enough
scheduler can let all 2000 goroutines interleave without ever actually racing on
the same instant, especially on a lightly loaded CI runner. It is better than
nothing, but it is not a reliable trigger.

---

## The Strong Approach: an Explicit Barrier

Force both goroutines to be provably mid-execution, both about to touch the racy
memory, before releasing either one onto the racy line — remove scheduler luck
from the equation entirely:

```go
// STRONG — an explicit barrier forces both goroutines to the racy line together
func TestCounter_ForcedInterleaving(t *testing.T) {
    c := &Counter{}

    var ready sync.WaitGroup // both goroutines signal "I am about to race" ...
    ready.Add(2)
    start := make(chan struct{}) // ... then both wait here until released together

    var wg sync.WaitGroup
    wg.Add(2)
    for range 2 {
        go func() {
            defer wg.Done()
            ready.Done() // "I have reached the starting line"
            <-start      // block until both goroutines are ready
            c.Increment()
        }()
    }

    ready.Wait()  // don't release until both goroutines are actually waiting
    close(start)  // release both onto the racy line at effectively the same instant
    wg.Wait()
}
```

The `ready`/`start` pair is the barrier: `ready.Wait()` doesn't return until *both*
goroutines have called `ready.Done()`, proving both are already running and blocked
immediately before the racy access — only then does closing `start` release them
onto `c.Increment()` at the same moment. This maximizes the chance `-race`'s
instrumentation actually observes the concurrent, unsynchronized touch, rather than
depending on whichever way the scheduler happened to interleave two independently
started goroutines.

---

## Run Repeatedly, Not Just Once

Scheduler nondeterminism means even a barrier-forced test is not a mathematical
guarantee on a single run — `-race`'s own sampling has some randomness in exactly
which memory accesses it instruments in a given run. Run the race-forcing test
multiple times as part of validating it actually catches the bug:

```
go test -race -run TestCounter_ForcedInterleaving -count=100 ./...
```

A test that fails intermittently under `-count=100` and passes clean under
`-count=1` is telling you the barrier narrowed the window but didn't fully close
it — tighten the barrier (e.g., ensure both goroutines' racy operations are as
close as possible with no additional non-deterministic work between the barrier
release and the racy line) rather than treating one clean run as sufficient
evidence either that a fix works or that a suspected bug doesn't exist.

---

## Applying This to a Fix, Not Just a Bug Hunt

The same barrier pattern verifies a *fix* holds, not only that a bug exists: write
the forced-interleaving test against the buggy version first (confirm it fails
under `-race`), apply the fix (a `Mutex`, a channel handoff, or `sync/atomic`
depending on which row of the sync-primitives table actually fits — see
`references/sync-primitives-decision-table.md`), then confirm the identical forced
interleaving test now passes clean under `-race -count=100`. This is the concurrent
equivalent of writing a failing test before the fix in ordinary TDD — the forced
interleaving is what makes the "before" state provably red rather than merely
suspected.
