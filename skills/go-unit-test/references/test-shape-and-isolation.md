# Test Shape, Parallel Safety and Isolation

Self-contained. Use when writing or fixing a Go unit test's structure, parallelism, time or randomness. Behaviour marked "seen" was run on Go 1.27.4.

## Table shape

One test function, a slice of named cases, one `t.Run` per case. `name` comes first and states behaviour ("equal is not higher"), not mechanics ("case 2"). One act per case: arrange, one call, assert. Cases that need different arrange or assert steps belong in another function, not behind flags.

Run one case (spaces become underscores, seen):

```bash
go test -run 'TestSensitivity_IsHigherThan/equal_is_not_higher' ./internal/domain
```

`-run` is split at `/`, one expression per subtest level.

Since Go 1.22 loop variables are per iteration, in modules whose `go.mod` declares 1.22 or later: do not write `tt := tt`.

## t.Parallel

Safe when the case owns all its data and doubles, which is the default. Unsafe when cases share anything mutable: a package-level variable, one fake, one random source.

| Trap | What happens | Instead |
|---|---|---|
| `defer` in the parent, `t.Parallel()` in subtests | The parent returns before the subtests run, so the deferred teardown runs first (seen) | `t.Cleanup` |
| `t.Setenv` or `t.Chdir` in a parallel test or under a parallel parent | Panic (seen) | Pass the value in as a parameter; otherwise that test and its parents stay serial, and every other test stays parallel |
| Package-level counter or shared fake | Data race; order-dependent results | Build it inside the subtest |

`go test -race` finds races that the run actually exercises; `-shuffle=on` finds order dependence. Both belong in the standard run.

## No real world

A unit test touches no file system, network, database, or clock and randomness it does not control. A test that needs a real database or broker is an integration test (`go-integration-test`). `testdata/` golden files for large output belong to `test-fixture-design`; unit cases stay as small literals inside the test, never in package scope.

| Dependency | Control |
|---|---|
| Current time | Pass `now time.Time` (or a clock port); use a fixed `time.Date` with an explicit zone |
| IDs | Pass them in; fixed constants |
| Randomness | Inject a seeded source: `rand.New(rand.NewPCG(1, 2))` repeats (seen). The global functions of `math/rand/v2` are always randomly seeded |
| Timers, timeouts, tickers | `testing/synctest` |

## testing/synctest

`synctest.Test` (Go 1.25 and later) runs the test in a "bubble" with a fake clock; `synctest.Sleep` arrived in 1.27. Inside a bubble:

- do not call `t.Run`, `t.Parallel` or `t.Deadline` (call `synctest.Test` inside each subtest);
- waiting on a mutex, I/O or a system call does not count as blocked, so it does not suit code that talks to anything real;
- every goroutine started must be able to finish: one still blocked when the test body returns panics with "deadlock: main bubble goroutine has exited but blocked goroutines remain" (seen). Cancel it, or sleep past its timer.

`time.Sleep` to wait for real work is never acceptable: it is either a race or a hidden integration test.
