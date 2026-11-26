# Checklist: Test Doubles

Run after `validate-test-doubles.sh` (the skill's script) is clean. The script finds text patterns; this list checks judgement.

## Choice
- [ ] Every dependency is classed managed or unmanaged with a reason; unclear ones are put to the product owner.
- [ ] Only consumer-defined ports are doubled.
- [ ] Managed dependencies are asserted by state; no call assertions on them under any name.
- [ ] Each mock asserts count and the arguments that matter; no stub is asserted on; order only where it is a rule.
- [ ] With an outbox, the handler test asserts the row and the relay test mocks the publisher.
- [ ] Responses stubbed for another service are checked against its contract, or the gap is an open question.

## Generated mocks
- [ ] moq, version pinned, directive beside the port, no hand edits, no `-skip-ensure`; any `-stub` has a reason.
- [ ] Each generated file ends `_moq.go`, is written by a directive and is committed.
- [ ] CI regenerates and fails on a changed or untracked file.
- [ ] The coverage filter and mutation settings exclude `_moq.go` by name; any filter matching only `_mock.go` is corrected; the exclusion register lists them.
- [ ] Optional, unverified: the generated header line was looked at; it is not used as the filter.

## Fakes
- [ ] Compile-time assertion; copies in and out; the port's errors; tenant scope from the design.
- [ ] One behaviour suite ran against the fake and the real adapter.
- [ ] Fake and support code are covered, or listed for approval; none is marked as generated.

## Proof and answer
- [ ] Each new test was seen to fail for the expected reason; tests ran, or are called unverified.
- [ ] The answer states class and double, what was replaced or refused and why, what stays the default, what helpers and generated files do unseen, coverage handling, the size note, decisions and what was run, and offers no way around a rule.
