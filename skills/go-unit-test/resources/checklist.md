# Go Unit Test Checklist

Copy and tick before hand-off.

## Cases
- [ ] Code classified by quadrant; overcomplicated code split first
- [ ] Rows derived by a named technique; collapsed or untried combinations stated
- [ ] Every rejection and failure path has a row; rejected calls prove nothing changed

## Shape
- [ ] Test written first and seen to fail for the expected reason
- [ ] Table with behaviour names; one act per case
- [ ] Parallel where the case owns its data; no parent `defer` with parallel subtests; no `t.Setenv` under `t.Parallel`
- [ ] No real file system, network, database, sleep, wall clock or unseeded randomness
- [ ] Asserts public behaviour; `errors.Is`/`errors.As`; got and want in every message
- [ ] Doubles follow `mock-generation`
- [ ] Fuzz target for untrusted input, with a bounded CI step

## Run
- [ ] `validate-go-unit-tests.sh` has no FAIL; each WARN judged
- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Line gate and branch gate run on the full suite; exit codes and counts recorded
- [ ] Every "no result" resolved by a code change or an approved exception; none reported as passing
- [ ] Coverage report filled: unmeasured cases, exclusions and their approval, excepted files
- [ ] Anything not run is called unverified
