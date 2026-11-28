# Triage in Python: Kill It, or Prove It Cannot Be Killed

Self-contained. Read for every mutant a run did not catch. The method is the triage method of `go-mutation-test`, which owns it for every language; this file applies it to mutmut's mutants, with cases from the cider-press lab (`../examples/01-lean-cider-press.md`), each run with mutmut 3.8.1 on 2026-11-28.

## The one question

For a mutant that survived: **does any input exist for which the original and the mutant give a different observable result?**

- **Yes: a real gap.** Add the missing row to the `parametrize` table (`python-unit-test`'s shape), test-first: see it fail against the mutant's behaviour, then it kills the mutant on the next run. Production code does not change.
- **No: equivalent.** Prove it by walking every input class, then record it: `equivalent`, with the walk in one line.

"Hard to test", "unlikely input", "the caller never does that" and "probably equivalent" are not proofs. If an input exists, the test is owed.

## Case 1: every line ran, a boundary survived (`is_late`)

```python
def is_late(minutes_after_start: int, grace_minutes: int) -> bool:
    return minutes_after_start > grace_minutes
```

Rows `(5, 15) → False` and `(40, 15) → True` run the line, so coverage is 100%. mutmut planted `>` → `>=`; it survived, because neither row sits on the boundary. **Real gap**: the row `(15, 15) → False` killed it on the next run.

## Case 2: an equivalent mutant (`crates_allowed`, a clamp)

```python
def crates_allowed(requested: int, limit: int) -> int:
    if requested > limit:
        return limit
    return requested
```

`>` → `>=`. Walk every input class: below the limit both return `requested`; above it both return `limit`; at `requested == limit` the original returns `requested` and the mutant `limit`, the same number. **Equivalent**: recorded once, with that walk as the reason. When the line was later rewritten as `if limit < requested:`, the mutant's diff changed, the record went stale and the run failed until the line was re-checked (seen).

## Case 3: an equality that a float satisfies (`juice_litres`)

```python
def juice_litres(apples_kg: int) -> int:
    return apples_kg * 6 // 10
```

`//` → `/` survived rows `(100, 60)` and `(15, 9)`: `60.0 == 60` and `9.0 == 9` are both true in Python. **Real gap**: a load that does not divide evenly, `(7, 4)`, killed it (`4.2 != 4`). A type checker rejects this mutant too (`float` returned where `int` is declared), but only a test makes it count as killed.

## Case 4: a loop bound (`pressings`)

`while remaining > 0` → `while remaining > 1` survived rows of 250, 200 and 0 kg. At 1 kg the original presses once and the mutant not at all: **real gap**, killed by `(1, 100, 1)`.

## Timed out

mutmut planted `remaining -= kg_per_press` → `remaining = kg_per_press` and → `remaining += kg_per_press`. Both timed out, and timed out again on the runner's recheck with a four-times longer limit: from a positive load the first never falls to 0 and the second only grows. Recorded as `timeout`, each with that one line. Never record a timeout without reading the code: a slow mutant is not an endless one (seen: a mutant that ran 0.77 s timed out under a tight limit and was killed on the recheck).

## Caught by type check

Only when the product sets `type_check_command`. Read the message the script prints (from mypy, in the lab: `Incompatible return value type (got "float", expected "int")`), confirm the mutation caused it rather than an already broken build, and record it as `not-viable` with that message. In the lab mypy took 15 of 27 mutants, most of which the tests would have killed: the setting turns test kills into record lines, so it is off by default.

## No tests is never recorded

No test reaches the function (the lab's `juice_litres` had no test file at first: all four of its mutants were `no tests`). Write the test, or, if the code truly cannot be tested, list an exclusion for the product owner. A record cannot cover it: nothing was tested.

## mutmut-specific shapes

| Mutant | Usually |
|---|---|
| `x = None`, an argument replaced by `None` or dropped | Killed by any test that uses the value; a survivor means the result is not asserted |
| `"text"` → `"XXtextXX"`, or upper/lower case | A survivor means no test checks the string (a message, a key); assert it, or record it only if the string truly never reaches an observer |
| A number `n` → `n + 1` | A boundary or constant nobody asserts; add the row |
| `break` → `return`, `continue` → `break` | Assert what the loop produced, not only that it returned |
| A survivor inside a function whose tests assert nothing about its result | The tests assert too little; fix the assertions before adding rows |

## Order of work

1. `no tests` first: a missing test is the biggest gap.
2. Survivors next, by the one question; write each missing row before recording anything.
3. Timed-out and type-checker-rejected ones last: read, confirm, record.
4. Run again. Repeat until every mutant is killed or recorded, or the product owner reviews what is left above 90%.
