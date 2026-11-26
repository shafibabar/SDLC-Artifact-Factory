# Native Fuzzing

Self-contained. Use for parsers, decoders, validators and anything taking untrusted input.

## Shape

- `FuzzXxx(f *testing.F)` in a `_test.go` file, with one `f.Fuzz` target. Name the file `<implementation>_fuzz_test.go`.
- Argument types are limited to string, []byte, signed and unsigned integers, floats and bool.
- Seed with `f.Add`: one ordinary value, the empty value, each known awkward one.
- Assert properties that hold for every input: no panic; on error, the documented error and zero result; on success, the invariants; parse then print then parse gives the same value.
- Fast, deterministic, no shared state. One execution over 1 second counts as a failure.

## What runs when

| Command | Runs |
|---|---|
| `go test ./...` | Only the seed corpus (`f.Add` and `testdata/fuzz/<Name>/`). **No fuzzing** |
| `go test -run='^$' -fuzz='^FuzzParse$' -fuzztime=30s ./internal/reading` | Generates inputs for 30 seconds |

`-fuzz` must match exactly one fuzz test in exactly one package (several packages are refused). Without `-fuzztime` it runs without limit. So CI needs one bounded step per target:

```yaml
- name: Fuzz reading.Parse
  run: go test -run='^$' -fuzz='^FuzzParse$' -fuzztime=30s ./internal/reading
```

The workflow step is not run here; the command was. How long to fuzz is not set by any source: record the figure chosen in the test strategy.

A failing input is minimised and written to `testdata/fuzz/<Name>/<hash>`. Commit it: it then runs on every plain `go test` as a regression case. Fix the code; never delete the file to get green. Coverage-guided growth needs AMD64 or ARM64.
