# The Verdict, the Record and the Scope

Self-contained. Read when judging a run, writing a record line, asking for a waiver, deciding what is in scope, or explaining how the mutation gate relates to the coverage gates. The rule is the product owner's (decision D048 and its follow-ups of 2026-11-25 and 2026-11-28); `test-pyramid` states it for every language; this file says how a Go run meets it. `check-go-mutation.sh` applies all of it.

## The rule

- **Every planted mutant is killed by a test, or recorded individually with the reason it cannot be**: the change does not alter behaviour. This replaced the earlier 60% target, which is rejected; so is any other percentage target.
- **Timed-out and compiler-rejected mutants** count as caught only once each is checked and recorded with a one-line reason; never automatically.
- **Result = (killed + individually recorded) / all planted mutants**, as counts. Gremlins' efficacy and mutant coverage are not used (they leave timed-out mutants out and count non-compiling ones as killed; `./gremlins-v0.6.0.md`).
- **100% passes.** **More than 90% and under 100%** fails unless the product owner reviews every mutant not caught and waives the gap with recorded comments; **90% or below has no waiver**. Computed from counts: waivable only if `caught x 10 > planted x 9`. Line coverage, branch coverage and the mutation result are each judged separately. A waiver covers one result, these counts for this source id; any change to the code or the record needs a new review, and so does the next release.

## How each mutant is classified

| Gremlins status | Runner's recheck | Counts as | What to do |
|---|---|---|---|
| KILLED | compiles | Killed | Nothing |
| KILLED | rejected by the compiler | Not caught until recorded `not-viable` | Check the compiler message, record it |
| TIMED OUT | killed (a test failed within the recheck timeout) | Killed | Nothing: it was a slow mutant, not an endless one |
| TIMED OUT | lived | Not caught until killed, or recorded `equivalent` | As for LIVED |
| TIMED OUT | timed out again | Not caught until recorded `timeout` | Check the mutated code really never finishes, record it |
| TIMED OUT | rejected by the compiler | Not caught until recorded `not-viable` | As above |
| LIVED | (none) | Not caught until killed, or recorded `equivalent` | Triage (`./triage-method.md`): write the test, or prove no input can tell it apart |
| NOT VIABLE | (none) | Not caught until recorded `not-viable` | Check and record |
| NOT COVERED | (none) | Not caught; **never recordable** | A test of its own package, or an approved exclusion |
| SKIPPED | (none) | Not planted | A release run with any SKIPPED is INVALID |

A record line matches a mutant by file, column, type and the fingerprint of its source line, and still matches when lines above it move. One that matches nothing (the code changed, or a test now kills it) fails the run until it is re-checked or removed: a stale record cannot be waived. A record of the wrong kind (equivalent for a timeout) fails too.

## Verdicts

| Verdict | When | Exit |
|---|---|---|
| PASS | Every planted mutant killed or recorded; or more than 90% with a waiver row naming this run and these counts | 0 |
| WAIVER-NEEDED | More than 90% and under 100%, no matching waiver | 3 |
| FAIL | 90% or below; or a stale or wrong record line | 1 |
| INVALID | No `run.txt` (the run did not finish), a missing, empty or unreadable report, a report of another commit or module, Gremlins' exit not 0, a `--diff` run judged as a release, SKIPPED or RUNNABLE in a release run, a KILLED or TIMED OUT mutant without a recheck line, a malformed record, a pending exclusion, nothing planted | 2 |

`--mode scheduled` prints the same verdict but exits 0 unless INVALID: scheduled runs report only, and are never waived.

**The run's identity.** `run.txt` holds the commit and a **source id**: a hash of the tracked `.go` files, `go.mod`, `go.sum`, `.gremlins.yaml` and `mutation/`. Adding the product owner's waiver row to the report is a commit of its own; the source id does not change, so the release re-run that reads the row matches it. A waiver row names the source id or the commit, with at least seven hex characters.

## Scope

- **All product code**, every package, at every product size (D048.2 and 2026-11-28). The earlier "domain and application packages only" is withdrawn: handlers, repositories, adapters and `cmd/` are in scope. A package left out is an **exclusion**: listed in `mutation/exclusions.txt` with a reason, for the product owner's approval; `pending` excludes nothing.
- **Generated code** is left out as the coverage gate leaves it out: any file carrying `// Code generated ... DO NOT EDIT.` before its `package` clause, and moq mocks by their `_moq.go` name. The script finds them itself and lists them.
- **Test support under the module's `internal/test/`** is left out as the class the product owner approved once for coverage (2026-11-27): listed in every report, test support only, never code that ships.
- **Files the coverage gate excepts** (`coverage-exceptions.txt`, approved) are passed as exclusions too: code the coverage gate does not measure has no test to kill a mutant.

## How the mutation gate relates to the coverage gates

| | Statement gate (`go-unit-test`) | Branch gate (`gobco`) | Mutation |
|---|---|---|---|
| Asks | Did each block run? | Was each condition both true and false? | Would a test notice if this operator changed? |
| Counts tests of | Any package (`-coverpkg=./...`) | The package itself | The package itself (Gremlins' coverage run and each mutant's `go test <package>`) |
| Runs | Every `make ci` | Every `make ci` | Before each release (blocks); scheduled between releases (reports) |

A NOT COVERED mutant means no test **of its own package** runs that line. After both coverage gates pass, this happens only where the statement gate counted another package's tests and the line has no condition for the branch gate to miss (observed: a handler's `return n * 500`, called only from another package's test, ran in the statement gate's profile and was NOT COVERED for Gremlins), or in a file behind a build tag the mutation run did not set (`MUTATION_TAGS`), or in an excepted file (pass the exceptions). The remedy is the branch gate's: give the package its own test. Coverage proves code ran; only an assertion kills a mutant, so 100% coverage with survivors is not a contradiction (`./triage-method.md`, the `IsLastPage` case).

## Research grounding

- Khorikov, *Unit Testing* (`research/testing/unit-testing-khorikov.md`): coverage is a gameable, lagging indicator; a surviving mutant is a **protection-against-regressions** gap, one of the four pillars, not a general quality score.
- Jorgensen, *Software Testing: A Craftsman's Approach* (`research/testing/software-testing-craftsman-jorgensen.md`): statement, branch and stronger criteria form a subsumption ladder; mutation is a separate axis, not a higher rung. Cite it for that argument only, not for mutation mechanics.
- Quigley (`research/testing/testing-vv-dictionary-quigley.md`): statement coverage is the weakest structural criterion; use the exact terms (statement, branch) rather than "line coverage" when the two gates are compared.
