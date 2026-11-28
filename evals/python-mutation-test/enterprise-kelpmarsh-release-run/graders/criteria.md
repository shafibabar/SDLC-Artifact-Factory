---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects running the release mutation run on publication: the release run is a full run that blocks the release and must finish before the release is published. A run started by publishing cannot stop a release that is already out.
2. It says scheduled runs between releases report only and do not block pull requests or builds. It accepts that those scheduled runs may target changed code only, while the release run covers all product code.
3. It rejects leaving `kelpmarsh/adapters/` and `kelpmarsh/api/` out silently: the scope is all product code, and a package left out is a listed exclusion with a reason, for the product owner's approval.
4. It rejects keeping the 9 record lines: a record line that matches no planted mutant fails the run, and that failure cannot be waived. The stale lines must be removed or the mutants checked and recorded again.
5. It rejects reusing the earlier waiver: a waiver is tied to a fingerprint of the code, the mutation setup and the record, so a later code change voids it. This release's 94% needs a fresh review by the product owner, with recorded comments, before it can be waived.
Fail if any of the 5 is missing.
