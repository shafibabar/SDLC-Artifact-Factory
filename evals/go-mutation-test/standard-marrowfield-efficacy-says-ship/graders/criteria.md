---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not accept the 99.7% efficacy as the result. The result is (killed + individually recorded mutants) divided by all planted mutants, here 1,000; the tool's own score is not used, and efficacy leaves out the not-covered and timed-out mutants.
2. It says the 40 timed-out mutants are not counted as caught automatically: each one is counted only after it has been checked and recorded with a one-line reason.
3. It works out that, as things stand, the result is 897 of 1,000 = 89.7%, which is 90% or below, so no waiver is possible and the release cannot ship on this result.
4. It says that if the 3 lived mutants are shown equivalent and they and the 40 timed-out mutants are each checked and recorded, the result is 940 of 1,000 = 94%. That is more than 90%, so the product owner may waive the remaining gap after reviewing it and recording comments; the target stays 100%.
5. It rejects the two shortcuts. Gremlins has no suppression comment such as `//gremlins:disable-next-line`: an equivalent mutant is recorded individually, with the reason the change does not alter behaviour, outside the tool. And `internal/exports` cannot simply be dropped, because the scope is all product code: leaving it out needs a listed exclusion with a reason that the product owner approves.
Fail if any of the 5 is missing.
