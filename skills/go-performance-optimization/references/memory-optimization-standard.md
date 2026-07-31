# Memory Optimization Standard

Full standard referenced from `SKILL.md`'s "Memory Optimization Standard" section.
Self-contained — reads without the parent body already in context. Covers the four
allocation-reduction techniques this repo applies once a profile (see
`references/profiling-workflow.md`) has proven a path is genuinely hot: preallocation
with a known bound, `sync.Pool` for high-churn objects, avoiding unnecessary interface
boxing, and `strings.Builder` over concatenation. Grounded in Donovan & Kernighan's
slice/map chapter (4) and escape-analysis treatment, and Harsanyi's optimization chapter
(12).

---

## Preallocate Slices and Maps

**The rule, stated generally: any slice or map whose maximum size is knowable before the
loop that fills it starts must be preallocated to that bound — never declared as a bare
`var` (or empty literal) and grown by `append`/index-assignment alone.** "Knowable ahead
of time" covers more cases than it first looks: a `LIMIT` already used in the query that
produced the rows, a fixed worker count, a known-length input slice being mapped 1:1, or
any size hint already sitting in a variable in scope. The rule does **not** apply when
the final size is genuinely unknown ahead of time — filtering an unbounded stream down to
matches, for instance — where a guessed capacity either wastes memory (guessed too high)
or triggers growth anyway (guessed too low, no benefit).

```go
// BAD — grows and reallocates the backing array repeatedly
records := []*kgo.Record{}
for _, m := range rows { records = append(records, toRecord(m)) }

// GOOD — the bound (len(rows), or a LIMIT/worker-count already in scope) is known
// before the loop starts; one allocation, no copying
records := make([]*kgo.Record, 0, len(rows))
for _, m := range rows { records = append(records, toRecord(m)) }

ids := make(map[uuid.UUID]struct{}, len(rows)) // size hint avoids rehashing
```

**Why this is a real cost, not a style nit.** `append` grows a nil/undersized slice by
successive reallocation-and-copy (roughly doubling below a threshold, ~1.25× above it)
every time capacity is exceeded — for N elements that means on the order of `log2(N)`
reallocations, each copying the *entire* slice built so far. Called once, this is noise;
called continuously (a relay's tick loop, a hot request path), it is a steady, entirely
avoidable source of both CPU (the repeated copying) and GC pressure (every intermediate
backing array becomes garbage the instant the next one replaces it).

**Canonical worked instance in this repo: `go-event-publisher`'s `drainOnce`.** The
relay's claim query already bounds `rows.Next()` to at most `r.batch` iterations —
`LIMIT $1` passes that exact same `r.batch` value — so `records` and `ids` preallocate to
`r.batch` at zero additional cost: the bound was already sitting on the struct, not
computed for the purpose. Full before/after and the batch-size tradeoff this bound
interacts with: `go-event-publisher`'s `references/batching-backpressure-and-idempotency.md`.
Any other loop in this repo shaped the same way — a `LIMIT`, a fixed fan-out length, a
1:1 map over a known-length input — is the same rule, not a special case of it.

---

## `sync.Pool` for High-Churn Allocations

For objects allocated and discarded at high frequency on a **profiled** hot path
(per-event scratch buffers, short-lived encode/decode byte slices), `sync.Pool` recycles
them instead of letting the allocator and GC handle each one fresh — cutting allocation
count and GC pressure on exactly the paths where that matters. Never reach for it without
a profile justifying it: pooling a rarely-allocated or long-lived object adds complexity
and can *increase* memory held (a pool keeps objects around between uses; a rarely-hit
path doesn't need that trade).

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}

func encode(env Envelope) ([]byte, error) {
    buf := bufPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufPool.Put(buf)
    if err := json.NewEncoder(buf).Encode(env); err != nil {
        return nil, err
    }
    out := make([]byte, buf.Len()) // copy out before returning buf to the pool
    copy(out, buf.Bytes())
    return out, nil
}
```

**The real correctness hazard, stated precisely: a pooled object must be reset/zeroed
before it is reused — on `Get`, or immediately before `Put` — because `sync.Pool` never
does this for you.** A `bytes.Buffer` not `Reset()` before its next use still holds the
*previous* caller's bytes at its front; a pooled struct with a slice or map field not
cleared still holds the previous caller's entries. This is a subtle, hard-to-find bug
class specifically because it doesn't crash or race — it silently prepends or leaks stale
data from one logically unrelated request into another's output, and only shows up as
occasional, hard-to-reproduce data corruption under load (when the pool is actually
reusing objects instead of allocating fresh ones, which happens more under contention).

The second hazard is a genuine data race, not just a correctness smell: **never retain a
reference to a pooled object after calling `Put`.** The moment `Put` returns the object to
the pool, the very next `Get` — potentially on a different goroutine — can receive that
same object. Holding onto it past `Put` means two goroutines now hold the same buffer,
and the race detector will catch the resulting concurrent mutation the moment a test
actually exercises it. The worked example above avoids both hazards: `Reset()` runs
immediately after `Get`, and the function copies the buffer's contents into a fresh slice
*before* `Put` runs (via `defer`), so nothing outlives the pool return.

---

## Avoiding Unnecessary Interface Boxing

Passing a concrete value through an `interface{}`/`any`-typed parameter on a hot path
forces a heap allocation a concretely-typed parameter would not have needed. The
mechanism is escape analysis (Donovan & Kernighan ch. 6.2; see `SKILL.md`'s cross-link to
`go-domain-model`'s receiver-type standard): once a value's identity is erased behind an
interface, the compiler generally cannot prove the value stays confined to the current
stack frame — an interface value is a two-word header (type descriptor + a pointer to the
data), and for anything larger than a machine word, or anything the compiler can't
statically prove is stack-safe once boxed, that data word points at a heap allocation.
**Verify, don't assume, on a specific type**: `go build -gcflags='-m' ./...` prints the
compiler's actual escape decisions ("moved to heap", "escapes to heap") for every
allocation site in a package — this is the concrete way to confirm a suspected boxing
allocation is real before optimizing around it, and the tool `go-domain-model`'s
receiver-type standard means when it says to verify allocation behaviour with this skill
rather than assume it.

The classic instance: `fmt.Sprintf("%d", n)` and `log.Printf("count=%d", n)` box every
variadic argument as `interface{}`, allocating on every call — harmless at request-log
volume, a measurable cost in a per-event hot loop processing thousands of records a
second. On a **profiled** hot path, prefer a purpose-built, concretely-typed formatter
(`strconv.AppendInt` into a reused buffer) over the convenience of `fmt`'s
reflection-and-boxing machinery. Off a hot path, `fmt`'s convenience wins outright — this
is not a blanket "avoid `fmt`" rule, it is a hot-path-only trade, gated the same way every
technique in this standard is: profile first, apply narrowly.

---

## `strings.Builder` vs. Concatenation

Concatenating strings with `+=` inside a loop is quadratic, not linear, in total cost:
Go strings are immutable, so each `s += part` allocates an entirely new string sized
`len(s) + len(part)` and copies **all** of `s`'s existing bytes into it, every iteration.
Building a string this way from N parts of roughly equal size copies on the order of
`O(N²)` total bytes, even though the final string is only `O(N)` bytes long.

```go
var b strings.Builder
b.Grow(estimatedLen)        // optional: one allocation if you can estimate the total
for _, part := range parts { b.WriteString(part) }
result := b.String()
```

`strings.Builder` writes into an internal, growable `[]byte` buffer using the same
amortized-doubling growth strategy `append` uses on a slice — total copying across N
writes is `O(N)`, not `O(N²)`. `String()` at the end is a zero-copy conversion of the
final buffer, not another allocation. Calling `b.Grow(estimatedLen)` when a size estimate
exists collapses the buffer's own internal growth to a single allocation, the same
preallocation principle as the slice/map rule above applied to a byte buffer instead of a
slice header.
