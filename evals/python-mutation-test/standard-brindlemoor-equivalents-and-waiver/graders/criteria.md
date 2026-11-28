---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects `# pragma: no mutate` for the equivalent mutants: the pragma removes the mutant from the planted count and leaves no record, since mutmut keeps no reason from the comment. Each equivalent mutant is instead recorded individually in a record file outside the code, with the reason that the change does not alter behaviour.
2. It rejects counting timeouts and type-checker catches as killed automatically: each one counts as caught only after it is checked and recorded with a one-line reason. Saying that a timed-out mutant a test kills when rerun with a longer time limit counts as killed does not fail this.
3. It rejects the badge, or any tool score, as the result: the result is (killed + individually recorded) divided by all planted mutants. Saying that the badge counts timeouts as killed or leaves some mutants out does not fail this.
4. It says 93% is more than 90%, so the product owner may waive the remaining gap after reviewing it and recording comments, while the target stays 100%. It says 89% cannot be waived, because at 90% or below there is no waiver, so the remaining mutants must be killed or individually recorded before release.
5. It keeps the coverage floor and fixes the mutation runs instead: the coverage flags come out of `addopts`, and `--no-cov` is passed to the mutmut test runs through `pytest_add_cli_args`.
Fail if any of the 5 is missing.
