---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects triggering on `release: types: [published]`, because that runs once the release is already public. The release run must block and finish before publication, for example by making the publishing job depend (`needs`) on the mutation job.
2. It says the release run covers all product code, not changed code only; running on changed code only (such as `--diff`) is allowed for runs between releases.
3. It says scheduled runs between releases report only; they are not a blocking check.
4. It replaces `@latest` with an exact, pinned Gremlins version (for example `@v0.6.0`), saying a pre-1.0 version is acceptable once pinned.
5. It says the built-in efficacy threshold cannot enforce the rule, giving at least one of these reasons: a threshold of 100 fails even a perfect run, or efficacy ignores not-covered and timed-out mutants. Instead, a check reads the JSON report written with `--output` and fails on any lived, not-covered or timed-out mutant that has no recorded reason.
Fail if any of the 5 is missing.
