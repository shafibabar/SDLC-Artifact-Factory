# Interpreting Survivors and the Coverage Relationship

Full grounding for `python-mutation-test`'s "Survived-Mutant Triage Workflow", "Mutation-Score
Threshold", and "Targeting" sections: the worked 100%-coverage-with-survivor example that proves
coverage is gameable, two fully worked triage dispositions (a real gap and a genuine equivalent
mutant), and how to decide which modules to keep in scope. Self-contained — restates the triage
steps and the 60% threshold below rather than assuming the parent `SKILL.md` body is in context.

---

## The Precise Relationship to Coverage

`python-makefile` enforces a **line-coverage** gate via `pytest --cov` on every `make ci` run.
This skill enforces **60% mutation score** on a narrower package set, on a weekly-plus-pre-release
schedule. These are not the same metric at two numbers — they answer two different questions, on
two different cadences:

| | Line coverage (`python-makefile`) | Mutation score (this skill) |
|---|---|---|
| Question answered | Did this line execute during any test? | Did a test notice when this line's behaviour changed? |
| Gate | line-coverage floor, every `make ci` (every PR) | 60%, weekly + pre-release |
| Scope | whole `src/` minus generated/mock files | `domain/`, `service_layer/` only |
| Gameable by | assertion-free tests that merely execute code | nothing comparable — killing a mutant needs a real behavioural assertion |
| A failure means | untested code shipped | a test runs this line but would not catch a real bug in it |

**Both gates can be simultaneously true and non-contradictory**: a module at 100% line coverage and
45% mutation score is not a measurement error — it is the exact failure mode mutation testing
exists to catch. The worked example below constructs it precisely.

---

## Worked Example: 100% Coverage, Survived Mutant

```python
# src/classification/domain/pagination.py

def is_last_page(page: int, page_size: int, total_items: int) -> bool:
    """Report whether `page` (0-indexed) is the final page of a collection of
    `total_items` items shown `page_size` at a time."""
    return (page + 1) * page_size >= total_items
```

```python
# tests/unit/domain/test_pagination.py — as originally written
import pytest
from classification.domain.pagination import is_last_page


@pytest.mark.parametrize(
    "page, page_size, total_items, expected",
    [
        ("early page is not last", 0, 10, 100, False)[1:],   # illustrative id in the name column
        (15, 10, 100, True),
    ],
)
def test_is_last_page(page, page_size, total_items, expected):
    assert is_last_page(page, page_size, total_items) is expected
```

Cleaned up to the idiomatic `python-unit-test` shape, the two cases are simply
`(0, 10, 100, False)` and `(15, 10, 100, True)`.

**This achieves 100% line coverage.** `is_last_page` is a single `return`; both cases execute it,
and `pytest --cov` reports the function at 100%. A naive reading says it is fully tested.

**A mutmut mutant on the `>=` survives.** Mutating `>=` to `>` produces:

```python
return (page + 1) * page_size > total_items
```

Run both existing cases against the mutant:

- `page=0`: `(0 + 1) * 10 = 10`. `10 > 100` is `False` — identical to the original's `10 >= 100 =
  False`. Same output.
- `page=15`: `(15 + 1) * 10 = 160`. `160 > 100` is `True` — identical to the original's `160 >= 100
  = True`. Same output.

Neither case sets `(page + 1) * page_size` to exactly `100` — the one input where `>=` and `>`
diverge. **The suite has 100% line coverage and cannot distinguish the correct function from one
with an off-by-one boundary bug**, because it never exercises the boundary itself. The line ran
twice and asserted a result both times, yet never touched the value that separates correct from
broken.

**The fix — triage step 3's "real gap" branch — is a new `parametrize` row:**

```python
(9, 10, 100, True),   # (9 + 1) * 10 == 100, exactly on the boundary
```

Against the mutant: `(9 + 1) * 10 = 100`. `100 > 100` is `False` — the mutant returns `False`, the
test expects `True`, the case fails. **Mutant killed.** Line coverage does not move (the function
already executed on every prior case); mutation score is what moved, because this is the first case
that asserts the value *at* the boundary rather than merely running the code near it.

---

## Two Worked Triage Dispositions

The two dispositions look identical in a `mutmut results` report — "Survived". The only way to tell
them apart is the same question asked honestly: *does a distinguishing input exist?*

### Disposition A — Real Gap (write the missing test)

The `is_last_page` example above **is** this disposition, worked in full: read the diff with
`mutmut show`, confirm the covering cases ran but did not fail, construct the input where original
and mutant diverge (`page=9`), find it absent from the `parametrize` table, add the row, rerun to
confirm the kill. Nothing in the production code changes — only the table gains its missing row.

### Disposition B — Genuine Equivalent Mutant (annotate, don't chase)

```python
# src/classification/domain/clamp.py

def clamp_page_size(value: int, maximum: int) -> int:
    if value > maximum:
        return maximum
    return value
```

A mutant on the comparison, `>` → `>=`:

```python
if value >= maximum:
    return maximum
return value
```

Walk every input class:

- `value < maximum`: both `>` and `>=` are `False` → both versions return `value`. Identical.
- `value > maximum`: both `>` and `>=` are `True` → both versions return `maximum`. Identical.
- `value == maximum`: original's `>` is `False` → falls through, returns `value`, which **equals**
  `maximum`. Mutant's `>=` is `True` → returns `maximum` directly. Both return `maximum`. Identical.

**No input exists, anywhere in the domain, for which this mutant's output differs from the
original's.** Prove it equivalent once by this exhaustive case walk over the function's small,
closed input space — do not chase it with an ever-more-specific test. The correct action is triage
step 3's "No" branch: annotate the source line so a future run does not resurface it as noise:

```python
    if value > maximum:  # pragma: no mutate  (>=/> equivalent: at value == maximum both branches
                         #   return maximum. No distinguishing input exists. Triaged 2026-07-31.)
        return maximum
```

A `# pragma: no mutate` with a **named, dated reason** is the discipline — an unexplained pragma is
indistinguishable from an unmaintained one. mutmut then never generates that mutant again, so it
stays out of the total and the equivalent-mutant fraction never erodes the score's meaning.

**Why these two are told back to back:** guessing "probably equivalent" to dodge writing a test
silently erodes the mutation score. `is_last_page` had a distinguishing input hiding in an untested
boundary; `clamp_page_size` provably does not. Triage is the discipline of actually answering the
question before choosing the branch.

---

## Which Modules to Keep in Scope

`paths_to_mutate` (in `references/mutmut-setup-and-score.md`) lists `domain/` and `service_layer/`
and nothing else. The reasoning, per module type:

| Module | In scope? | Why |
|---|---|---|
| `domain/` value objects, Aggregates | **Yes** | Business rules — where a survived mutant is most expensive and a weak assertion most dangerous. Highest triage priority. |
| `service_layer/` command/query handlers | **Yes** | Orchestrate domain logic; thin on collaborators, so mutation signal stays legible. Triaged after domain-layer survivors. |
| `adapters/` (`asyncpg`, `aiokafka`) | **No** | Humble Object (`python-repository-pattern`): correctness is verified by `python-integration-test` against a real Postgres/Redpanda, not by mutating a query string. A survived mutant here says "this wrapper doesn't re-implement its dependency's logic" — true by design, not a gap. |
| `entrypoints/` (FastAPI handlers) | **No** | Deserialize-and-delegate with no decision logic of their own; the FastAPI/Pydantic boundary is exercised by `python-integration-test`. Mutating them tests plumbing and buries domain survivors. |
| generated / migration modules | **No** | No hand-written logic worth mutating; keep them out of `paths_to_mutate` entirely. |

**Adding a new domain module** requires no configuration change: because `paths_to_mutate` lists
directory prefixes (`src/classification/domain/`), any module created inside `domain/` or
`service_layer/` is mutated automatically on the next scheduled run. A genuinely new top-level
package outside those two prefixes — which `python-project-structure` makes rare — requires an
explicit, reviewed addition to `paths_to_mutate`, never a silent broadening of scope.

---

## Threshold Justification, in Depth

60% is set below `python-makefile`'s line-coverage number for a structural reason, not an arbitrary
one: coverage's ceiling is a true 100% — every statement either ran or it did not, with no analog
to an equivalent mutant. Mutation score's ceiling is **below** 100% for any nontrivial function,
because some fraction of generated mutants — exactly the `clamp_page_size` shape above — are
provably equivalent and unkillable by any test. Setting the gate at 60% leaves deliberate headroom
for that fraction without naming a single universal equivalent-mutant rate (it varies by function
shape and is not a constant this repo has measured); still, requiring more than half of every
non-equivalent mutant to die is a real bar that disciplined parametrized testing
(`python-unit-test`) clears in practice, not a token gate. A bounded context where a missed
domain-layer mutant is unusually costly (a compliance-critical rule engine, a billing calculation)
raises this number in its own configuration per `sdlc-config-management`'s override pattern — the
same mechanism applied to a single number, not a different policy.
