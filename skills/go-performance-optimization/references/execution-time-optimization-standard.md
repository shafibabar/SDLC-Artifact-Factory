# Execution-Time Optimization Standard

Full standard referenced from `SKILL.md`'s "Execution-Time Optimization Standard"
section. Self-contained — reads without the parent body already in context. Covers the
discipline of speeding up execution time specifically (as distinct from reducing
allocations, `references/memory-optimization-standard.md`'s concern, though the two
overlap: fewer allocations usually also means less time spent in the allocator and GC):
algorithmic-complexity-first reasoning, a concrete decision test for premature
optimization, and the measure-first hard gate stated precisely enough to apply at code
review.

---

## Algorithmic Complexity Before Micro-Optimization

**Check the algorithm's complexity class at the hot spot before reaching for any
allocation trick, pooling, or micro-optimization.** An `O(n²)` algorithm processing
10,000 items performs on the order of 100 million operations; no amount of
preallocation, `sync.Pool`, or interface-boxing avoidance closes a gap that shape — only
replacing the algorithm with an `O(n log n)` or `O(n)` one does. The order of operations
that follows from this is fixed, not a matter of taste:

1. **Profile first** (`references/profiling-workflow.md`) to find where time is actually
   spent — never guess.
2. **At that exact hot spot, check the algorithm's complexity class** before touching
   anything else. A nested loop doing a linear search inside an outer loop
   (`for _, x := range xs { for _, y := range ys { if x.ID == y.ID { ... } } }`) is
   `O(n·m)`; replacing the inner linear search with a map built once outside the loop
   (`O(n+m)`) is very often a bigger win than every allocation technique in
   `references/memory-optimization-standard.md` combined, applied to the `O(n·m)`
   version.
3. **Only once the algorithm is already asymptotically right-sized for the input** does a
   constant-factor technique (preallocation, pooling, avoiding interface boxing,
   `strings.Builder`) earn its place — those techniques reduce the constant in front of
   the complexity term; they cannot change the term itself.

A profile that shows time concentrated in a function is not, by itself, evidence that
function's *constants* are the problem — it may just as easily be evidence that
function's *algorithm* is the problem, run against realistic input sizes. Check which
before choosing a fix.

---

## The Concrete Decision Test for Premature Optimization

Before applying any technique from this skill to a specific piece of code, answer three
questions in order. A "no" at step 1 or 2 means stop — there is no problem to optimize
yet, regardless of how the code reads:

1. **Has a profile identified this exact function or line as consuming a meaningful
   share of the time/allocation budget?** If no profile has run, or the profile doesn't
   point here, this is not a candidate — see the Measure-First Hard Gate below.
2. **Is there a stated SLO, budget, or benchmark this code is currently failing to
   meet?** Without a target, "faster" has no finish line, and a simple, obviously-correct
   version that already meets an unstated-but-real requirement is being traded for
   complexity that buys nothing measurable. If no budget exists, the simple version wins
   by default — set the budget first, don't optimize against a feeling.
3. **Would fixing the algorithm's complexity class matter more here than any
   constant-factor trick?** If yes, per the section above, fix the algorithm first;
   constant-factor techniques on an asymptotically wrong algorithm are polishing the
   wrong thing.

Only when all three answer favorably — profile-confirmed, budget-justified, algorithm
already right-sized — does reaching for a specific technique in
`references/memory-optimization-standard.md` or elsewhere in this skill earn the
complexity and readability cost it adds. This test is the operational form of
`SKILL.md`'s "measure only what a profile proves is hot" — a checklist, not a slogan.

---

## Measure-First: The Hard Gate

**No optimization change merges without a benchmark demonstrating the actual
improvement, compared old-vs-new via `benchstat` over multiple runs
(`references/benchmark-writing-standard.md`) — not a single run, not prose reasoning
about why a change "should" be faster.** A pull request whose only justification is "this
avoids an allocation" or "this should be faster" with no attached before/after numbers is
rejected on that basis alone, the same standing a bug fix with no regression test has in
this repo. This is a review-time gate applied to the specific PR making the change — a
different, and complementary, thing from `go-performance-test`'s automated CI gate, which
continuously re-checks every *subsequent* change against a committed baseline. This gate
answers "did this specific change actually help, with evidence"; that one answers "has
anything regressed since." Both matter; neither substitutes for the other.

**The full workflow this gate sits inside of, end to end:**

1. Write the simple, obviously-correct version first. Ship it if it meets the stated SLO
   — most code should stop here.
2. If an SLO is missed, or a profile independently surfaces a genuine hot path, **profile
   it** (`references/profiling-workflow.md`) — don't guess which function is slow.
3. At the profiled hot spot, **check algorithmic complexity first** (above) — fix the
   algorithm before reaching for a constant-factor technique.
4. Once the algorithm is right-sized, write a benchmark for that exact path with
   `b.ReportAllocs()` on (`references/benchmark-writing-standard.md`).
5. Apply the **minimal** technique that addresses what the profile actually showed — not
   every technique in this skill at once.
6. **Re-benchmark and compare via `benchstat` over `-count=10`-or-more runs.** Keep the
   change only if the comparison shows a real, statistically significant improvement (a
   low `p=` value, not a `~`-marked, statistically-indistinguishable delta).
7. Verify no correctness regression — `go test -race` on the changed package and its
   consumers.
8. **Document the why beside the change**: a short comment naming the profile and
   benchmark evidence that justified it, so a future reader doesn't "simplify" the
   optimization back into the simple version without realizing what it cost.

Skipping step 6 — shipping an optimization on the strength of steps 1–5 alone — is
exactly the failure mode this gate exists to block: intent and technique applied
correctly, with no evidence it actually worked.
