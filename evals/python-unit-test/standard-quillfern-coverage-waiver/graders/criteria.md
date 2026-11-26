---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects the 80% floor: the target is 100% of lines **and** 100% of branches, with branch measurement switched on.
2. It rejects coverage flags in `addopts`, because a run of a subset of tests would then fail the floor; the coverage flags and fail-under belong only on the full gate command (for example a make target or CI step). It does not move the floor into the coverage configuration's `fail_under` as the way to fix subset runs.
3. It judges the two figures separately, not combined: line coverage at 94% is above 90%, so only the product owner may waive that remaining gap, after reviewing it and recording comments; branch coverage at 88% cannot be waived and must be raised.
4. It rejects adding the pragma to the repository classes without approval: any exclusion other than machine-generated code must be listed with a reason and approved by the product owner. The default exclusions of `...` bodies and `if TYPE_CHECKING:` blocks are already approved as a class (no per-file approval) but are still listed in every report; saying this does not weaken the rule for the pragma.
5. It rejects the claim that 100% means every path is tested: alternatives inside one line (such as the conditional expression) and zero-iteration loops are not measured, and the report must state such unmeasured cases.
Fail if any of the 5 is missing.
