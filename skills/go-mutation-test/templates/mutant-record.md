# Mutant Record, Exclusions and Waiver Row

Self-contained. Copy the two files into the product when mutation testing is set up, and add a line only after checking the mutant. `check-go-mutation.sh` reads both; `validate-go-mutation-setup.sh` checks their format. Both files were used exactly in this form in the lab run of 2026-11-28.

## The record

One line per planted mutant that no test can kill. Never a line for a mutant a test could kill: write the test. Never a line for a NOT COVERED mutant: write a test of its own package, or list an approved exclusion.

### `mutation/mutant-record.txt`

```text
# Mutant record (go-mutation-test): one line per planted mutant that no test can kill.
# <file>:<line>:<col> | <TYPE> | equivalent|timeout|not-viable | <fingerprint> | <reason> | <who> <YYYY-MM-DD>
# Copy the line check-go-mutation.sh prints for the mutant, check it, then write the reason.
```

| Field | Content |
|---|---|
| `<file>:<line>:<col>` | As Gremlins reports it, module-relative. When lines move above it the record still matches (the script prints "Moved" so you update the line) |
| `<TYPE>` | Gremlins' mutant type, for example `CONDITIONALS_BOUNDARY` |
| Kind | `equivalent`: it LIVED and no input can make it behave differently. `timeout`: it timed out, and timed out again on the runner's recheck. `not-viable`: the compiler rejects it (Gremlins says NOT VIABLE, or KILLED and the recheck shows it does not compile) |
| `<fingerprint>` | Printed by the script: a hash of that source line. When the line's code changes, the record stops matching and the mutant must be checked again |
| `<reason>` | One line: why behaviour cannot change, why it never finishes, or the compiler's objection. "Hard to test" is not a reason: if any input can tell it apart, write the test |
| `<who> <YYYY-MM-DD>` | Who checked it, and when |

A record line that matches no planted mutant fails the run: the code changed, or a test now kills it. Re-check it or delete it. The report lists every record line with its reason, for the product owner.

## Exclusions

### `mutation/exclusions.txt`

```text
# Packages or files left out of mutation testing, each approved by the product owner.
# <path or folder/> | approved YYYY-MM-DD | <reason>      (or | pending | while awaiting approval)
# Generated code and internal/test/ are left out without an entry.
```

All product code is in scope. A line here is an exclusion the product owner approves, the same rule as the coverage gate's exclusions. A `pending` line excludes nothing: the verdict script refuses it (INVALID) and the validator fails an `exclude-files` pattern that covers it. Files listed in the coverage gate's `coverage-exceptions.txt` are passed too, because code the coverage gate does not measure has no tests to kill a mutant.

## The waiver row

Only after a release run ends in WAIVER-NEEDED (more than 90% and under 100%), and only after the product owner has reviewed every mutant not caught. Add it to the run's report under **Waivers**, in the table `test-pyramid` defines; the same row goes into the test strategy's Waivers table:

```text
| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| mutation | go | source <source id> (commit <sha>) | <caught>/<planted> | <the product owner's comments, as given> | <YYYY-MM-DD> |
```

- **Run** names the source id or commit the script printed. The source id stays the same when a later commit changes only the report, so the release re-run that reads the row still matches it.
- **Measured** is the exact counts the script printed, caught over planted, never a percentage.
- At 90% or below there is no waiver: the script does not read the row. A waiver covers that one result; the next release needs its own review.
