# Worked Example: Fan-Out / Fan-In

Full generic fan-in implementation referenced from the "Fan-Out / Fan-In" section of `go-concurrency-patterns/SKILL.md`. Fan-out distributes work across goroutines (see `errgroup`/Worker Pool in the parent skill); fan-in merges their results into one channel. The merge goroutine closes the output only after all producers finish — coordinated with a `sync.WaitGroup`.

```go
func fanIn[T any](ctx context.Context, sources ...<-chan T) <-chan T {
    out := make(chan T)
    var wg sync.WaitGroup
    wg.Add(len(sources))
    for _, src := range sources {
        go func() {
            defer wg.Done()
            for v := range src {
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }()
    }
    go func() { wg.Wait(); close(out) }() // close exactly once, after all producers done
    return out
}
```

This was verified directly: compiled and run against Go 1.23.4 with `go run -race`, fanning in two source channels (`{0,1,2}` and `{10,11,12}`) and summing the merged output — correct total (`36`), no data race reported, and the merged channel closes exactly once after both producers drain.

Each of `fanIn`'s goroutines has all three lifecycle properties required by this skill's Goroutine Lifecycle Rule: owned (spawned and joined by the enclosing `fanIn` call via the `WaitGroup`), exits on `ctx.Done()` or its source channel closing, and never leaves the merged channel open if a producer never appears — the `sources` slice is fixed at call time, so `wg.Add(len(sources))` always matches the eventual `wg.Done()` count.
