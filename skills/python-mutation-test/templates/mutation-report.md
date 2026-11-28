---
name: python-mutation-report
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: release or scheduled run, caught/planted, the verdict, and what awaits the product owner]
traces-to: [implement/test-strategy.md, commit [sha], source [source id], the release it gates or "scheduled"]
---

# Python Mutation Report for [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/python-mutation-report.md, written with Write. The product owner approves it.
     Fill it from check-python-mutation.sh's output and mutation-out/ (run.txt, results.txt, recheck.txt, show.txt).
     Copy counts and verdicts exactly; never a percentage, never mutmut's summary line, CI stats or badge.
     A scheduled run gets its own report, marked "report only". Delete this comment. -->

- **Run:** [release (whole project) / scheduled (functions changed since [tag])]; commit [sha]; source [source id]; [date]
- **Tools:** Python [version], mutmut [3.8.1, pinned], pytest [version]; recheck multiplier [60]
- **Commands:** `make mutation` [or `make mutation-changed`], as run

## Verdict

**[PASS / PASS, waived / WAIVER-NEEDED / FAIL / INVALID]**: [caught]/[planted] caught ([killed] killed by a test + [recorded] recorded).

[One sentence in words: every planted mutant is killed by a test or recorded with the reason it cannot be; or what is not, and why the release is held. A scheduled run blocks nothing.]

## Counts

| Planted | Killed by a test | Recorded: equivalent | Recorded: timeout | Recorded: not-viable | Not caught |
|---|---|---|---|---|---|
| [n] | [n] | [n] | [n] | [n] | [n] |

mutmut's own statuses for this run, for reference: killed [n], survived [n], no tests [n], timeout [n], caught by type check [n]. The runner's recheck of the timed-out ones: [n] killed, [n] survived, [n] timed out again.

## Recorded Mutants

Every line of `mutation/mutant-record.txt` that matched this run:

| Mutant | Kind | Reason | Checked by |
|---|---|---|---|
| [module.x_function__mutmut_n] | [equivalent / timeout / not-viable] | [reason, as recorded] | [who, date] |

## Not Caught

| Mutant | Status | Action |
|---|---|---|
| [mutant name, or "none"] | [survived / no tests / timeout, timed out again / caught by type check] | [the test that will kill it, or the record proposed] |

## Left Out

- **Generated code** (a "generated ... DO NOT EDIT" marker): [files, or "none"].
- **Test support under `tests/`** (fakes, fixtures, `conftest.py`; a class approved once by the product owner, never mutated, never code that ships): [files, or "none"].
- **Approved exclusions:** [path: reason, approved date; or "none"].
- **Approved lines not mutated** (a pragma or pattern the product owner approved): [file:line, or "none"].
- **Pending exclusions** (not excluded; the run stays INVALID until approved): [path: reason; or "none"].

## Not Planted

mutmut 3.8.1 never mutates module-level code, decorated functions (other than a lone `@staticmethod` or `@classmethod`), `__getattribute__`, `__setattr__` and `__new__`, some Enum methods, type annotations, calls to `len` and `isinstance`, complex parameter defaults or triple-quoted strings, so faults there are not tested by this report. [For a scheduled run: mutants outside the changed functions were not tested ([n]).]

## Waivers

| Measure | Language | Run | Measured | Product owner comments | Reviewed on |
|---|---|---|---|---|---|
| none | none | none | none | none | none |

<!-- Replace the row only after the product owner reviewed a release result above 90% and under 100%:
     | mutation | python | source <id> (commit <sha>) | <caught>/<planted> | <comments as given> | <YYYY-MM-DD> | -->

## Limits of This Report

A killed mutant shows that some test fails when that code changes; it does not show the test fails for the right reason. A recorded mutant rests on the reason written for it. Mutation testing measures the tests, not the product.

**For approval:** [the report itself; each new record line; each exclusion; any waiver asked for]
