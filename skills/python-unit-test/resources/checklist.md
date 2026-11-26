# Python Unit Test Checklist

Copy and tick before hand-off.

## Cases
- [ ] Code classified by quadrant; overcomplicated code split first
- [ ] Cases derived by a named technique; collapsed or untried combinations stated
- [ ] Every refusal and failure path has a case: exact exception, nothing changed, no event

## Shape
- [ ] Test written first and seen to fail for the expected reason
- [ ] Plain `assert`; behaviour names; one act per test; every parametrize row named
- [ ] Function-scoped fixtures; nothing mutable shared; no fixture imported
- [ ] No real file system, network, database, sleep, wall clock or unseeded randomness
- [ ] Asserts public behaviour; no private field; no assertion inside `pytest.raises` after the raising call
- [ ] Fakes for managed ports (the owners' fakes: copy on read, roll back by default); mocks only for unmanaged ports, asserted as awaited; stubs never asserted
- [ ] Settings match `pytest-settings.md`: pinned tools, auto mode, strict, warning filters, no coverage flags

## Run
- [ ] `validate-python-unit-tests.sh` has no FAIL; each WARN judged
- [ ] `pytest` passes
- [ ] `check-python-coverage.sh` run on the full suite; exit code, both counts and the skipped count recorded
- [ ] Old `--cov-fail-under` and any percentage check removed
- [ ] Every "no result" resolved by a change or an approved exception; none reported as passing
- [ ] Coverage report filled: unmeasured cases, skipped count, every approved-class line listed, other exclusions with reason and approval
- [ ] Anything not run is called unverified
