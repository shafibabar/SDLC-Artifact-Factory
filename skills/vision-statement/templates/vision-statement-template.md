# Vision Statement — Artifact Template

Self-contained. Copy everything below the line into `artifacts/<product>/strategy/vision-statement.md` and replace every `[bracketed]` value. Delete the optional "Telling the vision" section if you didn't produce one, and the "Parent Vision" section unless this is a product-area vision that passed the skill's four sub-vision tests.

---

```markdown
---
name: vision-statement
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the future this vision commits to, e.g. "Vision: SMB compliance teams prove what sensitive data they hold in minutes, without it leaving their boundary."]
owner: product-strategist
traces_to: [the problem statement / decision this vision answers]
---

# Vision Statement

[The vision — a logline of ≤ 60 words with the protagonist as subject: who, the future state, why it matters, the durable bet]

**Today:** We [one specific verb] for [the protagonist] so that [the outcome they experience now].

## Components

| Component | Value |
|---|---|
| Protagonist | [the specific user group whose world changes] |
| Today's need | [the underlying need, not the surface want] |
| Future state | [what is observably true for them in 3–5+ years] |
| Why it matters | [the stakes] |
| Durable bet | [the lasting, technology-agnostic belief that makes it reachable] |

## What This Vision Rules Out

- [Tempting direction 1] — [why the vision says no]
- [Tempting direction 2] — [why]
- [Tempting direction 3, optional] — [why]

## North Star Implication

**[Metric name]** — [definition and unit]. [One line on why moving it means the vision is being achieved.]

## Parent Vision (product-area visions only)

**Parent:** [link to the product or company vision this one serves]
**Slice it delivers:** [the named part of the parent's future state, or the distinct protagonist it serves and why the parent depends on them]
**Rolls up into:** [the parent north star this one's north star feeds]

## Telling the Vision (optional)

[A 120–180-word told version for onboarding, investors or stakeholders — see the skill's telling technique. It never replaces the logline above.]
```
