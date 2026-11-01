---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. It begins with a frontmatter block containing at least name, version, phase, owner, created and a one-sentence summary, with phase "ideate"; and it explicitly accounts for each of QA-1, QA-2 and QA-3 by ID (for example in an "inputs consumed" mapping or a "traces to" column), saying which NFR each became.
2. NFRs are written as quality-attribute scenarios: each NFR states, as separate parts or columns, at least a stimulus, the environment or conditions (for example the Sunday 18:00–20:00 peak and its load), and a response measure with a number; most of them also name a source and the affected part of the system and the response. Latency is expressed as a percentile (for example P95), not an average. Availability is expressed with recovery measures (for example RTO and/or RPO, or time to detect/recover after a failure), not only an uptime percentage.
3. Targets distinguish a minimum acceptable value from a target value (for example Planguage "Must" and "Plan", or "minimum" and "target"), and "instantly" and "99.9%" are not simply copied as targets without either a stated reason or being turned into a measurable value with conditions.
4. The UK data rule is cited as BR-4 (the business rule in the FRD) rather than written as a new, standalone rule of its own; and the artifact includes a deployability requirement (deploying and/or rolling back a change without a manual step or downtime) and does NOT list DORA delivery metrics (deployment frequency, lead time for changes, change failure rate) as non-functional requirements of the product (mentioning them as optional process targets owned elsewhere is fine).
Fail if any of the four is missing.
