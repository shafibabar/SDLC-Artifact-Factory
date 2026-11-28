# Triage: Kill It, or Prove It Cannot Be Killed

Self-contained. Read for every mutant a run did not catch. This skill owns the mutation triage method for every language (one owner per language-neutral method, W3-D17); `python-mutation-test` applies it by name. The two Go cases below were carried over from this skill's earlier version and re-run with Gremlins v0.6.0 in the rowing-boat lab (`../examples/01-lean-rowing-boat-hire.md`).

## The one question

For a mutant that lived: **does any input exist for which the original and the mutant give a different observable result?**

- **Yes: a real gap.** Write the missing assertion, usually the boundary row the table lacks, in the package's own test file, test-first style: see it fail against the mutant's behaviour, then it kills the mutant on the next run. Production code does not change.
- **No: equivalent.** Prove it by walking every input class, then record it: `equivalent`, with the walk in one line.

"Hard to test", "unlikely input", "the caller never does that" and "probably equivalent" are not proofs. If an input exists, the test is owed.

## Case 1: 100% coverage, a surviving mutant (`IsLastPage`)

```go
func IsLastPage(page, pageSize, totalItems int) bool {
	return (page+1)*pageSize >= totalItems
}
```

The test had two rows: `(0, 10, 100) → false` and `(15, 10, 100) → true`. Both statements run: 100% statement coverage, and the branch gate has no condition here to report. Gremlins planted `>=` → `>` (CONDITIONALS_BOUNDARY) and `page+1` → `page-1` (ARITHMETIC_BASE); both LIVED:

- `>`: `10 > 100` is false and `160 > 100` is true, exactly as with `>=`.
- `page-1`: `-10 >= 100` is false and `140 >= 100` is true, again identical.

Neither row puts `(page+1)*pageSize` exactly on `totalItems`, the one place the versions part. **Real gap.** The row `(9, 10, 100) → true` kills both: `100 > 100` is false, and `80 >= 100` is false. Coverage did not move; the mutation result did. This is Khorikov's point made concrete: coverage proves code ran, never that an assertion would notice a regression.

## Case 2: an equivalent mutant (`Seats`, a clamp)

```go
func Seats(requested, capacity int) int {
	if requested > capacity {
		return capacity
	}
	return requested
}
```

`>` → `>=`. Walk every input class:

- `requested < capacity`: both false, both return `requested`.
- `requested > capacity`: both true, both return `capacity`.
- `requested == capacity`: the original returns `requested`, the mutant `capacity`: the same number.

No input differs. **Equivalent**: record it once, with that walk as the reason, and do not chase it with a contrived test. The record keeps it from being re-triaged every run, and its fingerprint makes it come back for checking when that line's code changes.

The two cases look identical in Gremlins' output ("LIVED CONDITIONALS_BOUNDARY"). Only the question tells them apart.

## Equivalent by construction

Some mutants cannot differ whatever the code: Gremlins v0.6.0 maps `%=` to `%=` under INVERT_ASSIGNMENTS (the planted file is unchanged), and on a binary `-` it plants INVERT_NEGATIVES and ARITHMETIC_BASE as the same `+`. The first always lives: record it as `equivalent` with that reason. The second is killed or lives together with its twin.

## Timed out

A mutant that timed out under Gremlins is rechecked by the runner with a generous timeout. If a test then fails, it counts as killed; if the tests pass, it is a survivor (triage it as above). If it times out again, read the mutated code: an `i++` turned `i--` against `i < count` never ends. Record it as `timeout`, saying why it never finishes. Never record a timeout without reading the code: a slow test is not an endless loop, and raising the recheck timeout is the remedy there.

## Does not compile

Gremlins plants operators without knowing types: `"MERE" + "-"` becomes `"MERE" - "-"`, which Go rejects. Gremlins calls it KILLED; the runner's compile check shows it was never tested. Read the compiler message, confirm it is the mutation (not a broken build), and record it as `not-viable` with that message. If many such mutants come from one construct, that is expected: string concatenation produces two per `+`.

## NOT COVERED is never recorded

No test of the mutant's own package runs that line. Write a test of that package (the branch gate already asks every package with conditions for its own tests), or, if the code truly cannot be tested, list an exclusion for the product owner. A record cannot cover it: nothing was tested.

## Order of work

1. NOT COVERED first: a missing test is the biggest gap.
2. LIVED next, by the one question; write each missing row before recording anything.
3. Timed-out and non-compiling ones last: read, confirm, record.
4. Run again. Repeat until every mutant is killed or recorded, or the product owner reviews what is left above 90%.

When the same code has many survivors, the tests assert too little (a call with no check of the result), not too few cases: fix the assertions before adding rows.
