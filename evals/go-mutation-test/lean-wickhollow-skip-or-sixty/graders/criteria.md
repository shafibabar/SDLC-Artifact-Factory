---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says mutation testing is not skipped at lean: every product size, lean included, gets the full testing treatment, and that includes mutation testing.
2. It says 100% coverage does not make mutation testing redundant: coverage shows the code ran, not that a test would fail if the code's behaviour changed, so a surviving mutant is a regression-protection gap that coverage cannot reveal.
3. It rejects the 60% target: every planted mutant must be killed by a test or recorded individually with the reason it cannot be, because the change does not alter behaviour. It also says the target is 100% and only a result of more than 90% may be waived, by the product owner after review with recorded comments; at 90% or below there is no waiver.
4. It corrects the configuration: Gremlins' keys are nested (`unleash.threshold.efficacy`, `unleash.exclude-files`), not the flat `threshold-efficacy` or an `excludes` list. It also says leaving out `internal/store` is allowed only as a listed exclusion with a reason that the product owner approves, because the scope is all product code.
5. It rejects the by-hand quarterly run: a full mutation run before each release blocks the release and finishes before publication. It also says the mutation report is approved by the product owner, not by the developer who ran it.
Fail if any of the 5 is missing.
