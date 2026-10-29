---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. It begins with a frontmatter block containing at least name, version, phase, owner, created and a one-sentence summary, with phase "ideate".
2. It has a prioritisation agreement (or equivalently named section) before the bins that states who decides priority (the product owner) and what is dropped first when the release is under pressure, or how a disputed Must is escalated.
3. US-6 is a Must, and the artifact states that it is a legal or licensing Must that is added to the walking skeleton (for example at drop-off) so the Must list and the skeleton stay identical. The other skeleton stories (US-1, US-2, US-4, US-5) are Musts, or any one found to have a workaround is moved off the skeleton and replaced by a named manual step. None of US-3, US-7, US-8 or US-9 is a Must.
4. US-7 is NOT a Must: the artifact explains that Kano-Basic is a different axis from MoSCoW (a satisfaction class, not a release guarantee) and/or that a workaround exists, while it may keep US-7 as a Should placed late in the cut order.
5. The non-Must stories are given an explicit cut order (the order they would be dropped), and US-3 (the Delighter) is not the first thing dropped.
Fail if any of the five is missing.
