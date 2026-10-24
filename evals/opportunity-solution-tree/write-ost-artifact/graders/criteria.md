---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. It begins with a frontmatter block containing at least name, version, phase, owner, created and a one-sentence summary, with phase "ideate"; and its root is the KR's metric with baseline 60% and target 85%, explicitly labelled a product outcome.
2. The opportunities are nested under parents that are steps of the customer's experience (for example schedule, get paid, chase, pay), are written in the customer's voice, and each cites at least one interview by its ID (for example 2026-10-05-t-1 or t-1) or is marked as an assumption; repeated opportunities heard in more than one interview are merged into one with all their citations (not listed twice). One single target opportunity is named.
3. Under the target opportunity it gives at least three candidate solutions carried forward together, at least one of them non-software (a process, message or policy change rather than a feature).
4. It lists assumptions labelled by type using the types desirability, viability, feasibility, usability and ethical, including at least one ethical assumption; and it gives assumption tests whose success criteria are numeric thresholds (for example "at least 4 of 6 …") stated as set before the test runs.
Fail if any of the four is missing.
