---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. It begins with a frontmatter block containing at least name, version, phase, owner, created and a one-sentence summary, and the phase is "ideate" (not "strategy" or "discovery").
2. Every persona is labelled assumption-based (proto / provisional), and the label states that it was written by an AI agent (or the requirements-analyst agent), what it was inferred from (e.g. the product description), and that no user research or interviews were done. No persona is labelled research-based, interview-grounded or validated.
3. Every persona is given an explicit type, with exactly one primary per interface (each primary tied to a named surface, e.g. the front-desk booking screen or the tablet day list); the clinic owner is a separate customer/buyer persona, not merged with a user; the patients are a "served" persona (affected but never using the product, no interface designed for them); and there is a negative persona (anti-persona).
4. For each PRIMARY persona, goals are separated into end goals and experience goals (life goals optional), and the persona has validation questions that ask about a specific past event (e.g. "the last time…") rather than hypotheticals. (Secondary, supplemental, customer, served and negative personas may be shorter.)
Fail if any of the four is missing.
