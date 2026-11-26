# Golden Files and Stored Event Fixtures

Self-contained. Use for large expected output, or for events and messages that old data or other services produce.

## Golden files

A golden file in `testdata/` (a directory the Go toolchain ignores) holds the expected output; the test compares against it. Commit it and review its diffs like code.

**Use when** the output is large and stable (a rendered report, a response body, a serialized event) and inline text would hide the test. **Do not use** for a few values: assert them.

1. **Normalize before writing and before comparing:** replace only the values that legitimately differ per run. Better, control them (fixed clock, fixed ID) so nothing needs replacing. Over-normalizing blanks the thing under test.
2. **Missing file is a failure**, never silently created.
3. **Regenerate deliberately**, one test in one package: `go test ./internal/report -run TestRefundStatement -update`. A custom flag exists only in test binaries that define it, so `go test ./... -update` fails elsewhere.
4. **Read the diff** before committing. It is a change in behaviour: if unintended, fix the code; if intended but it changes what a user or consumer sees, show it to the product owner.
5. CI never runs with the update flag.

## Stored event fixtures

For stored or published events, keep a sample of **every historical type and version** as a committed file, and test that today's readers and converters still handle each one (Young). Without them a converter change can break a replay unnoticed.

- Capture the sample when that version ships. Write synthetic values in the real wire shape.
- **Never edit or regenerate an old sample** to make a test pass. The stored events in production did not change; fix the reader or converter.
- A new version or a new type adds a file. Removing one needs the event retired, with a record.
- Test the converter chain from each old sample to the current shape, including the default given to every added field: the default must be true of old events.

## Other message fixtures

Build current-version messages with a builder, using fixed event IDs and times. For duplicate delivery, publish the identical message twice and wait for proof that the second was consumed before asserting. Contract fixtures belong to `go-contract-test` and `python-contract-test`.
