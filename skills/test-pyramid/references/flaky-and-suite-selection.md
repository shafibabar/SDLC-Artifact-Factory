# Suite Selection, Smoke Safety and Flaky Tests

Self-contained. Use when deciding when a suite runs, how it is selected, or what to do with an unstable test. Language skills hold the commands; this file holds the rules.

## When suites run

| Suite | Runs | Kept apart by |
|---|---|---|
| Unit, integration, contract | Every pull request, in the fast check; coverage gate here | Default selection |
| Quick browser journeys with mocked services | A separate pull-request job, not inside `npm run ci` | Test project or tag |
| Full end-to-end | Nightly and before release | Go build tag, Python marker, Playwright project |
| Live-environment smoke | On promotion, read-only | Its own selector |
| Mutation | Monthly and before release (`go-mutation-test`, `python-mutation-test`) | Its own job |
| Performance, load, chaos | As the strategy records, from the owning skill's cadence | Go build tag, Python marker |

"Before release" means the run finishes before publication, not after it.

## Smoke and destructive safety

- Smoke is read-only and separately selected. A journey that creates or deletes data is not smoke.
- Go build tags only add files: `-tags smoke` still compiles every untagged file. Mark destructive files so the smoke build leaves them out (for example `//go:build e2e && !smoke`) or place them in another directory.
- A destructive test refuses to start against any address not known to be throwaway.
- A selector that matches zero tests fails the job.

## Flaky tests

A test that passes and fails on unchanged code is a fault to fix.

| Layer | Automatic retries | Detection |
|---|---|---|
| Unit, integration, contract, performance, load, chaos, mutation | 0 | Differing results on the same code |
| End-to-end | 1, no third attempt | Failed, then passed on the retry |

1. Record each flaky result: test, run, both outcomes, trace ID. A retried pass is flaky, not green. Playwright's default does not fail a run for it, so the record or a fail-on-flaky setting must surface it.
2. Quarantine: an end-to-end test that flakes more than once across recent runs, or a lower-layer test as soon as it is shown nondeterministic. Tag it, run it in a non-blocking job, and in the same change open a tracked issue with a deadline (two weeks unless the strategy says otherwise).
3. Before the deadline, find the cause (timing, shared state, order, resource limits) and restore it; or delete it with a record saying why and what proves the behaviour now. A bare skip is deletion without a record.
4. A quarantined test proves nothing. If a coverage gap, an uncaught mutant or an unproven Must Have criterion results, that gate is red until a stable test replaces it.
5. A growing quarantine list points at the environment, waits or test data: fix those first.
