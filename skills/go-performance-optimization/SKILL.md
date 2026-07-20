---
name: go-performance-optimization
description: >
  Teaches mechanical-sympathy Go performance work — writing low/zero-allocation
  code (value vs pointer and escape analysis, slice/map preallocation,
  strings.Builder, sync.Pool, GC pressure reduction) AND measuring it (benchmarks
  with ReportAllocs, pprof CPU/heap/block/mutex profiles, go tool trace, and
  runtime.ReadMemStats). The governing discipline is measure-first: optimise only
  what a profile proves is hot. Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, performance, allocation, escape-analysis, sync-pool, pprof, benchmark]
---

# Go Performance Optimization

## Purpose

Performance work in Go is the discipline of mechanical sympathy — writing code that cooperates with how the runtime and hardware actually behave — combined with the discipline of measurement. The two are inseparable: you do not optimise code you have not profiled, and you do not claim a speedup you have not benchmarked.

The governing rule, ahead of every technique below: **measure first.** A profile identifies the hot path; everything else is premature optimisation that trades clarity for nothing. Most code should be simple and obvious; a small, profiled minority earns the techniques here.

---

## Part 1 — Measure First

### Benchmarks with allocation reporting

Every performance-critical function has a benchmark that reports allocations. The allocation count is often a better optimisation signal than raw time, because allocations drive GC pressure.

```go
func BenchmarkClassifyEnvelopeMarshal(b *testing.B) {
    env := sampleEnvelope()
    b.ReportAllocs()          // report allocs/op and bytes/op
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, _ = json.Marshal(env)
    }
}
```

```
BenchmarkClassifyEnvelopeMarshal-8   1_250_000   954 ns/op   320 B/op   4 allocs/op
```

Compare before/after with `benchstat` over multiple runs — a single run is noise.

### pprof — find the real bottleneck

| Profile | Finds | Enable |
|---|---|---|
| CPU (`runtime/pprof` or `-cpuprofile`) | Where CPU time goes | `go test -cpuprofile cpu.out -bench .` |
| Heap (`-memprofile`) | What allocates / leaks memory | `go test -memprofile mem.out -bench .` |
| Block | Goroutines blocked on sync/channels | `runtime.SetBlockProfileRate` |
| Mutex | Lock contention | `runtime.SetMutexProfileFraction` |

```bash
go test -bench=Classify -cpuprofile=cpu.out -memprofile=mem.out ./...
go tool pprof -http=:0 cpu.out      # flame graph in browser
go tool pprof -top -alloc_objects mem.out
```

In production, expose `net/http/pprof` on a **separate, internal-only** admin port — never the public API port.

### go tool trace — latency and scheduling

For latency problems (not throughput), the execution tracer shows goroutine scheduling, GC pauses, network blocking, and syscall delays that pprof's sampling misses.

```bash
go test -trace=trace.out -bench=Pipeline ./...
go tool trace trace.out
```

### runtime.ReadMemStats — stability under load

To evaluate stability under a soak/stress test, sample `runtime.ReadMemStats` and watch `HeapAlloc`, `Mallocs - Frees` (live objects), and `NumGC`. Steady live-object count under sustained load means no leak; monotonic growth means one.

---

## Part 2 — Write Allocation-Aware Code

Apply these **only** where a profile shows the path is hot. Each trades a little simplicity for fewer allocations / less GC pressure.

### Value vs pointer, and escape analysis

Escape analysis decides whether a value lives on the stack (cheap, freed automatically) or the heap (GC-managed). Returning a pointer, storing into an interface, or capturing in a closure tends to push a value to the heap.

```bash
go build -gcflags='-m' ./...    # prints escape decisions: "moved to heap", "escapes to heap"
```

- Prefer **value types** for small, short-lived structs — they stay on the stack.
- Use **pointers** when the struct is large (copying costs more than indirection) or must be mutated.
- Avoid needlessly boxing values into `interface{}`/`any` on hot paths — it forces a heap allocation.

### Preallocate slices and maps

When the size is known or estimable, preallocate capacity to avoid repeated growth-and-copy.

```go
// BAD: grows and reallocates the backing array repeatedly
records := []*kgo.Record{}
for _, m := range rows { records = append(records, toRecord(m)) }

// GOOD: one allocation, no copying
records := make([]*kgo.Record, 0, len(rows))
for _, m := range rows { records = append(records, toRecord(m)) }

ids := make(map[uuid.UUID]struct{}, len(rows)) // size hint avoids rehashing
```

### strings.Builder for string assembly

Concatenating strings in a loop with `+` allocates a new string each iteration. `strings.Builder` writes into a growable buffer once.

```go
var b strings.Builder
b.Grow(estimatedLen)        // optional: one allocation if you can estimate
for _, part := range parts { b.WriteString(part) }
result := b.String()
```

### sync.Pool for high-frequency short-lived objects

For objects allocated and discarded at high frequency (per-event buffers, scratch byte slices), `sync.Pool` recycles them, cutting GC pressure. Profile-justify it — pools add complexity and are wrong for long-lived or rarely-allocated objects.

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

Always `Reset` on get (or before put), and never retain a reference to a pooled object after `Put`.

### Reducing GC pressure

Fewer, larger allocations beat many small ones. Reuse buffers (pool), preallocate, prefer value semantics on hot paths, and avoid per-request maps/closures in middleware. The goal is a flat allocation rate under steady load.

---

## The unsafe Package

`unsafe` (e.g., zero-copy `[]byte`↔`string`) is **forbidden unless** a benchmark proves a material win on a genuinely hot path *and* the use is reviewed and commented with the profile that justifies it. The default answer is no — correctness and clarity outrank micro-optimisation.

---

## Optimisation Workflow

1. Write the simple, correct version. Ship it if it meets the SLO.
2. If an SLO is missed, **profile** to find the actual hot path (don't guess).
3. Write a benchmark for that path (`ReportAllocs`).
4. Apply the minimal technique; **re-benchmark**; keep the change only if `benchstat` confirms a real win.
5. Verify no regression in correctness (`go test -race`) and document the why.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measure-first | Optimisations backed by a profile + benchmark | Speculative optimisation with no data |
| Benchmarks on hot paths | `BenchmarkXxx` with `ReportAllocs` for perf-critical funcs | Performance claims with no benchmark |
| Allocation awareness | Preallocated slices/maps; value types on hot paths | Repeated `append` growth; needless heap escapes |
| Pool used correctly | `sync.Pool` reset on get, not retained after put, profile-justified | Pool for long-lived objects; retained references |
| Cardinality/GC | Flat allocation rate under load; stable live-object count | Monotonic heap growth; allocation storms |
| unsafe gated | No `unsafe` unless benchmarked, reviewed, commented | `unsafe` for unproven micro-gains |

---

## Anti-Patterns

- **Optimising from intuition** — "maps are slow", "reflection is the problem" — without a profile. The hot path is almost never where instinct says it is.
- **Benchmarking once and believing it** — single-run numbers are noise; laptops thermal-throttle mid-run. Multiple runs plus `benchstat` or the claim doesn't count.
- **`sync.Pool` as a cargo cult** — pooling long-lived or rarely-allocated objects adds complexity and can *increase* memory held. Pools earn their place only on profiled allocation storms.
- **Retaining a pooled object after `Put`** — the next `Get` hands the same buffer to another goroutine; the resulting data race corrupts silently.
- **pprof on the public port** — `net/http/pprof` on the API listener exposes heap contents and a DoS lever. Internal admin port only.
- **Trading clarity for unmeasured nanoseconds** — an unreadable "fast" version that benchmarks identical to the simple one is pure cost. Keep the simple version.
- **Optimising against the SLO you don't have** — without a latency/throughput target, "faster" has no finish line. The SLO decides whether the simple version already wins.

---

## Output Format

Produces Go benchmarks and profile-justified optimisations (the optimisation lives in the relevant package; the evidence lives beside it):

```
*_test.go                      (BenchmarkXxx with b.ReportAllocs())
docs/perf/<path>-profile.md    (the profile + benchstat evidence for any non-obvious optimisation)
```
