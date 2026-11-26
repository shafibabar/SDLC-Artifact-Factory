---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says plain `go test` runs only the fuzz test's seed corpus; real fuzzing needs a separate CI step using `-fuzz` that matches exactly one fuzz test in one package, bounded with `-fuzztime`.
2. It says the failing inputs fuzzing writes under `testdata/fuzz/` should be committed (or kept) so they run afterwards as regression tests.
3. It says combining `t.Setenv` with `t.Parallel` (on the test or any parent) panics, and gives a fix such as dropping the parallelism for those tests or passing the region in as a value instead of through the environment.
4. It replaces the real 30-second sleep with a fake clock using `testing/synctest` (available from Go 1.25). Also suggesting an injected clock does not fail this, but `testing/synctest` must be mentioned.
5. It removes the call-count assertion on the exchange-rate stub: a stub only supplies input, so the test asserts the resulting behaviour or output instead.
6. It corrects the hook claim (the hook checks that a matching test file exists, not which file is older) and still requires the test to be written before the implementation, rejecting the timestamp workaround.
Fail if any of the 6 is missing.
