---
name: go-mutation-report
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: release or scheduled run, caught/planted, the verdict, and what awaits the product owner]
traces-to: [implement/test-strategy.md, commit [sha], source [source id], the release it gates or "scheduled"]
---

# Go Mutation Report for [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/go-mutation-report.md, written with Write. The product owner approves it.
     Fill it from check-go-mutation.sh's output and mutation-out/ (run.txt, gremlins.json, recheck.txt).
     Copy counts and verdicts exactly; never a percentage, never Gremlins' "efficacy" or "mutator coverage".
     A scheduled run gets its own report, marked "report only". Delete this comment. -->

- **Run:** [release (whole module) / scheduled (changed since [tag])]; commit [sha]; source [source id]; [date]
- **Tools:** Go [version], Gremlins [v0.6.0, pinned]; build tags [none / tags]
- **Commands:** `make mutation` [or `make mutation-changed`], as run

## Verdict

**[PASS / PASS, waived / WAIVER-NEEDED / FAIL / INVALID]**: [caught]/[planted] caught ([killed] killed by a test + [recorded] recorded).

[One sentence in words: every planted mutant is killed by a test or recorded with the reason it cannot be; or what is not, and why the release is held. A scheduled run blocks nothing.]

## Counts

| Planted | Killed by a test | Recorded: equivalent | Recorded: timeout | Recorded: not-viable | Not caught |
|---|---|---|---|---|---|
| [n] | [n] | [n] | [n] | [n] | [n] |

Gremlins' own statuses for this run, for reference: KILLED [n], LIVED [n], NOT COVERED [n], TIMED OUT [n], NOT VIABLE [n], SKIPPED [n]. The runner's recheck: [n] KILLED did not compile; [n] TIMED OUT were killed, [n] lived and [n] timed out again.

## Recorded Mutants

Every line of `mutation/mutant-record.txt` that matched this run:

| Mutant | Type | Kind | Reason | Checked by |
|---|---|---|---|---|
| [file:line:col] | [TYPE] | [equivalent / timeout / not-viable] | [reason, as recorded] | [who, date] |

## Not Caught

| Mutant | Type | Status | Action |
|---|---|---|---|
| [file:line:col, or "none"] | [TYPE] | [LIVED / NOT COVERED / TIMED OUT, timed out again / does not compile] | [the test that will kill it, or the record proposed] |

## Left Out

- **Generated code** (by the `Code generated ... DO NOT EDIT.` marker or `_moq.go`): [files, or "none"].
- **Test support under `internal/test/`** (a class approved once by the product owner; never code that ships): [files, or "none"].
- **Approved exclusions:** [path: reason, approved date; or "none"].
- **Pending exclusions** (not excluded; the run stays INVALID until approved): [path: reason; or "none"].

## Not Planted

Gremlins plants only its eleven operator types, all enabled here. It never removes a statement or a `!`, changes a literal's value (only the sign, through `-`), swaps a function call or alters a returned value, so faults of those kinds are not tested by this report. [For a scheduled run: mutants outside the changed lines were not planted ([n] SKIPPED).]

## Waivers

| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| none | none | none | none | none | none |

<!-- Replace the row only after the product owner reviewed a release result above 90% and under 100%:
     | mutation | go | source <id> (commit <sha>) | <caught>/<planted> | <comments as given> | <YYYY-MM-DD> | -->

## Limits of This Report

A killed mutant shows that some test fails when that operator changes; it does not show the test fails for the right reason. A recorded mutant rests on the reason written for it. Mutation testing measures the tests, not the product.

**For approval:** [the report itself; each new record line; each exclusion; any waiver asked for]
