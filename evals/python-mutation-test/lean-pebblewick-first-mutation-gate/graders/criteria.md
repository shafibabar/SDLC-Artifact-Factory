---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects point 1: mutation testing applies to a lean product the same as to any other size, and its scope is all product code. Leaving the services, adapters or API code out is allowed only as a listed exclusion with a reason, for the product owner's approval.
2. It rejects the unpinned install and pins mutmut to one exact version, for example `mutmut==3.8.1`. A version range or "latest" does not pass.
3. It says `paths_to_mutate` and `tests_dir` are deprecated and replaces them with `source_paths`, and it says `runner` is not a mutmut 3 setting: an unknown key is silently ignored, so it does nothing.
4. It says surviving mutants do not make `mutmut run` exit non-zero, so exit 0 does not mean the gate passed. The gate must read each mutant's status, for example from `mutmut results --all`, and fail on any mutant that is neither killed nor individually recorded with a reason.
5. It rejects the 60% gate: the target is 100%, meaning every planted mutant is killed by a test or individually recorded with the reason it cannot be, namely that the change does not alter behaviour. Mentioning that the product owner may waive a result of more than 90% after review with recorded comments does not fail this; any fixed threshold below 100% used as the pass mark does.
Fail if any of the 5 is missing.
