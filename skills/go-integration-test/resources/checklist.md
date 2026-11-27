# Go Integration Test Checklist

Copy and tick before hand-off.

## Harness
- [ ] Real engine, pinned tag matching production; no mock or substitute
- [ ] Address only from the started container; no `DATABASE_URL`
- [ ] Real migrations applied by the deployment's tool
- [ ] One set of containers per package, started in `TestMain`, stopped with errors reported
- [ ] `-short` skips each integration test; no exit in `TestMain`, no build tag, no Docker skip
- [ ] Start retried only for containers, bounded and logged; no test retried

## Tests
- [ ] Test written first and seen to fail
- [ ] Rollback unless a named reason needs a commit; commit tests own their keys or database
- [ ] Cleanup registered before the first write, covers every table written, reports errors
- [ ] Expected database errors run in a savepoint
- [ ] No `time.Sleep`; polls have a deadline and report the last error
- [ ] Duplicate and "nothing happened" assertions come after proof of consumption
- [ ] Isolation, deduplication and refusal tests went red with the check removed
- [ ] Relay and global readers have their own database and topic
- [ ] Tenant denial (if any) runs as the application role, with an allowed read in the same test
- [ ] Changed migration: up, down, up, and previous release's statements on the new schema
- [ ] Every documented API promise and error branch asserted, with stored effect; no invented limits

## Run
- [ ] `validate-go-integration-tests.sh` has no FAIL; each WARN judged
- [ ] `go test -race -shuffle=on ./...` passes with Docker
- [ ] Statement and branch gates run on the full suite; counts and exit codes recorded
- [ ] Report lists every file left out as `internal/test/` test support; nothing that ships is in the folder or imports it
- [ ] Any other unmeasured gap is a pending exclusion or tested; none called passing
- [ ] No container left running
- [ ] Anything not run is called unverified
