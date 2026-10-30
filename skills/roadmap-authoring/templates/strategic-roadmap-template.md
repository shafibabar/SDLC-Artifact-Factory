# Strategic Roadmap — Artifact Template

Self-contained. Copy everything inside the fence into `artifacts/<product>/strategy/roadmap.md` and replace every `[bracketed]` value.

- **lean:** keep it to one page; 2–5 themes in total; leave Stage as an optional column; delete the Target customer and Product area columns, the scores table and the "Review pre-wiring" table, and keep the "Decisions you may question" list.
- **standard:** fill Stage on every row; add Target customer when the GTM strategy names more than one segment; fill the scores table and the pre-wiring table; produce an external view (themes and stages only, no dates, disclaimer on top) as a separate section or file.
- **enterprise:** repeat each horizon table per product area (swimlanes), or add a Product area column; fill cross-area dependencies; record the pre-wiring order; produce the audience views in `../references/alignment-and-views.md`.

Confidence: **High** (> 80%), **Medium** (50–80%), **Low** (< 50%) is this plugin's calibration, not the source book's. Candidate solutions appear in **Now only**. No date appears past Now unless a committed OKR carries it.

---

```markdown
---
name: strategic-roadmap
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the problems in Now and what they serve, e.g. "Roadmap for lunch-tracker: ordering inside the chat first (KR1.1–1.2), settling up next, menus deliberately excluded."]
owner: product-strategist
profile: [lean | standard | enterprise]
format: [now-next-later | quarters-then-halves]
traces_to: [strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/okrs.md]
---

# Strategic Roadmap — [Product]

## Disclaimer

This roadmap is a statement of intent and direction. It reflects our current understanding and will change as we learn. Confidence describes how sure we are about the sequence and scope of each theme, not how important it is. Nothing here is a delivery date unless it is marked **committed**.

## Vision

[One line pointing at the vision] — North Star: [the vision's metric, as the vision states it].

## Objectives this roadmap serves

**Guiding policy (from the kernel):** [one line]

| Objective | Type | Key Results |
|---|---|---|
| O1 — [from the OKR set] | [committed / aspirational] | KR1.1 [metric]; KR1.2 [metric] |

## How this was prioritised

**Weakest link:** [the capability that caps the rest, and its theme — or "none identified"]
**Framework:** [critical path | value / effort / confidence scorecard | Kano for table stakes] — [one line on how it was applied]

| Theme | Value (1–5) | Effort (1–5) | Confidence (0.5 / 0.8 / 1.0) | Score |
|---|---|---|---|---|

## Now — [current quarter or cycle]

| Theme (customer problem) | Serves | Candidate solutions (bets) | Stage | Confidence | Reinforces | Dependencies | Target customer | Product area |
|---|---|---|---|---|---|---|---|---|
| [problem, in the customer's words] | KR1.1 | We believe [Initiative] will move KR1.1 | [research / discovery / development / beta / released] | High | [other Now theme or policy clause] | [—] | [segment] | [area] |

## Next — [next quarter or two]

| Theme (customer problem) | Serves | Stage | Confidence | Dependencies | Target customer | Product area |
|---|---|---|---|---|---|---|
| [problem] | KR1.2 / [Objective] | [discovery] | Medium | [Now theme] | | |

## Later — [following half or more]

| Theme (customer problem) | Serves | Confidence | Next segment it unlocks | Product area |
|---|---|---|---|---|
| [problem] | [Objective, annual Objective, or Guiding policy: clause] | Low | [segment, if any] | |

## Not On This Roadmap

| Declined direction or request | Excluded by (guiding-policy clause or diagnosis) |
|---|---|
| [direction] | Guiding policy: "[clause]" — [one line on why] |

## Review pre-wiring

<!-- lean: replace this table with "Decisions you may question" — 2–4 bullets, each with its reason -->

| Order | Stakeholder | Date | Concern | How the draft answered it |
|---|---|---|---|---|

## Revision history

Revise at: each OKR cycle · discovery results · a strategy kernel revision · the Ideate story map (its release slices test Now) · a KR no theme can move (flagged to `okr-authoring`).

| Date | Trigger | What moved | What was dropped | The learning that caused it |
|---|---|---|---|---|
| [YYYY-MM-DD] | First version | — | — | — |
```
