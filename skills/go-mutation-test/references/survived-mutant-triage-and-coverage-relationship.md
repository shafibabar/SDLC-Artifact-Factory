# Survived-Mutant Triage and the Coverage Relationship

Full grounding for `go-mutation-test`'s "Survived-Mutant Triage Workflow" and "Mutation-Score
Threshold" sections: the worked 100%-coverage-with-survived-mutant example that closes the loop
`go-unit-test`'s `references/coverage-by-quadrant.md` opens (coverage is gameable; this is the
proof), two fully worked triage dispositions (a real gap and a genuine equivalent mutant), and the
precise relationship between mutation score and `go-makefile`'s 80% line-coverage threshold.
Self-contained — restates the triage steps and both threshold numbers below rather than assuming
the parent `SKILL.md` body is in context.

---

## The Precise Relationship to Line Coverage

`go-makefile`'s `references/coverage-and-benchmark-standard.md` enforces **80% line coverage** via
`check-coverage.sh`, gated on every `make ci` run. This skill enforces **60% mutation score** on a
narrower package set, on a monthly-plus-pre-release schedule. These are not the same metric at two
different numbers — they measure two different questions, on two different cadences, via two
different mechanisms:

| | Line coverage (`go-makefile`) | Mutation score (this skill) |
|---|---|---|
| Question answered | Did this line execute during any test? | Did a test notice when this line's behaviour changed? |
| Gate | 80%, every `make ci` run (every PR) | 60%, monthly + pre-release |
| Scope | Whole repo minus `cmd/`, generated/mock files | `internal/domain/...`, `internal/application/...` only |
| Gameable by | Assertion-free tests that merely execute code | Nothing comparable — killing a mutant requires an actual behavioural assertion |
| What a failure means | Untested code shipped | A test exists over this line, but wouldn't catch a real bug in it |

**Both gates can be simultaneously true and non-contradictory**: a package at 100% line coverage
and 45% mutation score is not a measurement error — it is the exact failure mode mutation testing
exists to catch. The worked example below constructs this precisely.

---

## Worked Example: 100% Line Coverage, Survived Mutant

```go
// internal/domain/pagination.go

// IsLastPage reports whether page (0-indexed) is the final page of a
// collection of totalItems items at pageSize items per page.
func IsLastPage(page, pageSize, totalItems int) bool {
    return (page+1)*pageSize >= totalItems
}
```

```go
// internal/domain/pagination_test.go — as originally written
func TestIsLastPage(t *testing.T) {
    tests := []struct {
        name                          string
        page, pageSize, totalItems    int
        want                          bool
    }{
        {"early page is not last", 0, 10, 100, false},
        {"page well past the end is last", 15, 10, 100, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := IsLastPage(tt.page, tt.pageSize, tt.totalItems); got != tt.want {
                t.Errorf("IsLastPage(%d,%d,%d) = %v, want %v", tt.page, tt.pageSize, tt.totalItems, got, tt.want)
            }
        })
    }
}
```

**This achieves 100% line coverage.** `IsLastPage` is a single return statement; both subtests
execute it. `go test -cover` reports the function at 100%, and a naive reading says the function
is fully tested.

**A Gremlins mutant on the `>=` survives.** Mutating `>=` to `>` produces:

```go
return (page+1)*pageSize > totalItems
```

Run both existing cases against the mutant:

- `page=0`: `(0+1)*10 = 10`. `10 > 100` is `false`. Identical to the original's `10 >= 100 =
  false`. Same output.
- `page=15`: `(15+1)*10 = 160`. `160 > 100` is `true`. Identical to the original's `160 >= 100 =
  true`. Same output.

Neither test case sets `(page+1)*pageSize` to exactly `100` — the one input where `>=` and `>`
actually diverge. **The suite has 100% line coverage and cannot distinguish the original function
from a version with an off-by-one boundary bug**, because it never exercises the boundary itself.
This is precisely `go-unit-test`'s coverage-is-gameable warning made concrete: the line ran twice,
and the test asserted a `want` both times, yet the assertion never touched the one value that
would have separated correct from broken.

**The fix — the triage's step-3 "real gap" branch:**

```go
{"page exactly at the boundary is last", 9, 10, 100, true}, // (9+1)*10 == 100
```

Against the mutant: `(9+1)*10 = 100`. `100 > 100` is `false` — the mutant returns `false`, the
test wants `true`, the case fails. **Mutant killed.** Line coverage does not change (the function
was already executing on every prior case) — mutation score is what moved, because the new case
is the first one that actually asserts the value at the boundary rather than merely running the
code near it.

---

## Two Worked Triage Dispositions

### Disposition A — Real Gap (write the missing test)

The `IsLastPage` example above **is** this disposition, worked in full: read the diff (`>=`→`>`),
confirm the covering tests ran but didn't fail, construct the input where original and mutant
diverge (`page=9`), find it absent from the table, add it, rerun to confirm the kill. Nothing
about the production code changes — only the test table gains the row it was missing.

### Disposition B — Genuine Equivalent Mutant (annotate, don't chase)

```go
// internal/domain/clamp.go
func Clamp(value, max int) int {
    if value > max {
        return max
    }
    return value
}
```

A mutant on the comparison, `>` → `>=`:

```go
if value >= max {
    return max
}
return value
```

Walk every possible input class:

- `value < max`: both `>` and `>=` are `false` → both versions return `value`. Identical.
- `value > max`: both `>` and `>=` are `true` → both versions return `max`. Identical.
- `value == max`: original's `>` is `false` → falls through, returns `value`, which **equals**
  `max`. Mutant's `>=` is `true` → returns `max` directly. Both return `max`. Identical.

**No input exists, anywhere in the domain, for which this mutant's output differs from the
original's.** This is a mutant to prove equivalent once, by this exhaustive case walk over the
function's entire input space (small and closed enough here to do by hand), not to chase with an
ever-more-specific test. The correct action is step 3's "No" branch: annotate it in
`.gremlins.yaml`'s `excludes` list with the reasoning above in the comment, dated, so a future
triage pass doesn't re-derive the same walk from scratch.

**Why these two examples are told back to back:** the surface symptom — "mutant survived" — looks
identical in a Gremlins report for both. The only way to tell them apart is the same question,
asked honestly: *does a distinguishing input exist?* `IsLastPage` had one, hiding in an untested
boundary. `Clamp` provably doesn't. Triage is the discipline of actually answering that question
before deciding which of the two workflow-step-3 branches applies — guessing, or defaulting to
"probably equivalent" to avoid writing a test, silently erodes the mutation score's meaning.

---

## Threshold Justification, in Depth

60% is set below `go-makefile`'s 80% line-coverage number for a structural reason, not an
arbitrary one: line coverage's ceiling is a true 100% — every statement either ran or it didn't,
with no analog to an equivalent mutant. Mutation score's ceiling is **below** 100% for any
nontrivial function, because some fraction of generated mutants — exactly the `Clamp` shape above
— are provably equivalent and will never be killed by any test, no matter how thorough. Setting
the gate at 60% rather than a higher number leaves deliberate headroom for that fraction without
naming a single universal equivalent-mutant rate (it varies by function shape and is not a
constant this repo has measured); setting it meaningfully above 50% still requires that more than
half of every non-equivalent mutant actually gets killed, which is a real bar disciplined
table-driven testing (`go-unit-test`) clears in practice, not a token gate. A bounded context
where the domain-layer cost of a missed mutant is unusually high (a compliance-critical rule
engine, a billing calculation) raises this number in its own `.gremlins.yaml` per
`sdlc-config-management`'s override pattern — the same mechanism, applied to a single number, not
a different policy.
