# Mutant Record, Exclusions and Waiver Row

Self-contained. Copy the two files into the product when mutation testing is set up, and add a line only after checking the mutant. `check-python-mutation.sh` reads both; `validate-python-mutation-setup.sh` checks their format. Both files were used exactly in this form in the lab run of 2026-11-28 (`../examples/01-lean-cider-press.md`).

## The record

One line per planted mutant that no test can kill. Never a line for a mutant a test could kill: write the test. Never a line for a `no tests` mutant: write the test, or list an approved exclusion. The record lives outside the code: a `# pragma: no mutate` in the source is not a record (the mutant is then never planted, so nobody reviews it).

### `mutation/mutant-record.txt`

```text
# Mutant record (python-mutation-test): one line per planted mutant that no test can kill.
# <mutant name> | equivalent|timeout|not-viable | <fingerprint> | <reason> | <who> <YYYY-MM-DD>
# Copy the line check-python-mutation.sh prints for the mutant, check it, then write the reason.
```

| Field | Content |
|---|---|
| `<mutant name>` | As mutmut names it: `<module>.x_<function>__mutmut_<n>`, or `<module>.xǁ<Class>ǁ<method>__mutmut_<n>` for a method (the `ǁ` is part of the name). When the number shifts because a mutant was added earlier in the same function, the record still matches (the script prints "Renamed" so you update the line) |
| Kind | `equivalent`: it survived, and no input can make it behave differently. `timeout`: it timed out, and timed out again on the runner's longer recheck. `not-viable`: it was `caught by type check` (only when the product sets `type_check_command`) |
| `<fingerprint>` | Printed by the script: a hash of the mutant's `mutmut show` diff. When the function's code near the change moves or changes, the record stops matching and the mutant must be checked again |
| `<reason>` | One line: why behaviour cannot change, why it never finishes, or the type checker's objection. "Hard to test" is not a reason: if any input can tell it apart, write the test |
| `<who> <YYYY-MM-DD>` | Who checked it, and when |

A record line that matches no planted mutant fails the run, and the failure cannot be waived: the code changed, or a test now kills it. Re-check it or delete it. The report lists every record line with its reason, for the product owner.

## Exclusions

### `mutation/exclusions.txt`

```text
# Code left out of mutation testing, each approved by the product owner.
# <path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>   (or | pending | while awaiting approval)
# Generated code (a "generated ... DO NOT EDIT" marker) and test support under tests/ need no entry.
```

All product code is in scope. A line here is an exclusion the product owner approves, the same rule as the coverage gate's exclusions:

| Kind | Covers | Comes from |
|---|---|---|
| `file`, `folder` (path ends with `/`) | A file or folder under `src/` that mutmut does not mutate | A `do_not_mutate` or `only_mutate` setting, or `source_paths` leaving it out |
| `lines <fingerprint>` | One line that a `# pragma: no mutate` (any form) or a `do_not_mutate_patterns` match keeps unmutated | The validator and the verdict script print the line to propose, with its fingerprint (a hash of the line's text; edit the line and the approval lapses) |

A `pending` line excludes nothing: the verdict script refuses the run (INVALID) until it is approved, and refuses any hidden code without a line.

## The waiver row

Only after a release run ends in WAIVER-NEEDED (more than 90% and under 100%), and only after the product owner has reviewed every mutant not caught. Add it to the run's report under **Waivers**, in the table `test-pyramid` defines; the same row goes into the test strategy's Waivers table:

```text
| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| mutation | python | source <source id> (commit <sha>) | <caught>/<planted> | <the product owner's comments, as given> | <YYYY-MM-DD> |
```

- **Run** names the source id or commit the script printed. The source id stays the same when a later commit changes only the report, so the release re-run that reads the row still matches it; any change to code, tests, `pyproject.toml`, `uv.lock` or `mutation/` gives a new source id and voids the waiver.
- **Measured** is the exact counts the script printed, caught over planted, never a percentage.
- At 90% or below there is no waiver: the script does not read the row. A waiver covers that one result; the next release needs its own review.
