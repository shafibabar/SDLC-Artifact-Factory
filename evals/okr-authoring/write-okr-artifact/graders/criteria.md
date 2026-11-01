---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. A frontmatter block with name, version, phase, owner, created AND a one-sentence summary field, and it traces to the vision and the strategy kernel (not the roadmap).
2. Every Objective is explicitly labelled committed or aspirational; the pilot promise (special orders in Shelfwise the same day) is treated as committed, and at least one other Objective is aspirational.
3. Each Key Result has a baseline (a measured value, or an explicitly marked pre-launch / not-yet-measured baseline with a date or plan for the first reading; an invented number or a bare blank fails), a target and a starting confidence, and confidence differs by type: committed KRs start around 90% or higher, aspirational KRs around 50% (not one flat 70% for all).
4. It uses the vision's North Star (share of requested titles on the shelf) without defining a new North Star.
5. It includes a health-metrics section AND a weekly check-in log section (it may be empty).
6. No Key Result is an output (e.g. "launch", "ship", "build" a feature); outputs, if mentioned, appear as Initiatives.
Fail if any of the six is missing.
