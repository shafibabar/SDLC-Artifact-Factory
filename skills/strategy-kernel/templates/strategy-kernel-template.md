# Strategy Kernel — Artifact Template

Self-contained. Copy everything below the line into `artifacts/<product>/strategy/strategy-kernel.md` and replace every `[bracketed]` value. At the lean profile keep each part to a short paragraph (about 150 words in total) and delete the "Challenges set aside" table and the "Parent kernel" section. Delete "Parent kernel" everywhere except an enterprise product-line kernel.

---

```markdown
---
name: strategy-kernel
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the crux and the policy, e.g. "Strategy: firms won't switch AR tools mid-year, so we win the month-end close for 5–50-person firms and import their history."]
owner: product-strategist
traces_to: [the vision statement this kernel serves; the competitive analysis and stakeholder map it read]
---

# Strategy Kernel

## Diagnosis

[A short judgement, 2–5 sentences: what is going on and what makes it hard. End on the crux.]

**Crux:** [the one challenge that is both important and addressable]

| Challenge set aside | Why not the crux |
|---|---|
| [challenge] | [important but not addressable / addressable but not important / follows from the crux] |

## Guiding Policy

[One approach to the crux, 1–3 sentences.]

**Relies on:** [the advantage, leverage, focus or wave of change it uses — and where the evidence is, e.g. the competitive analysis]

**Rules out:**
- [Tempting direction 1] — because [reason traced to the diagnosis]
- [Tempting direction 2] — because [reason]
- [Tempting direction 3, standard and enterprise] — because [reason]

## Coherent Actions

| # | Action | Reinforces |
|---|---|---|
| 1 | [concrete move; a chain-link fix goes first] | [action # or the policy clause it makes stronger] |
| 2 | [concrete move] | [action #] |
| 3 | [concrete move] | [action #] |

## Proximate Objectives (hand-off to the OKR set)

- [The next feasible position the policy implies — no numbers; the OKR set adds the Key Results]
- [Optional second objective; lean has one]

## Review Trigger

**This diagnosis is wrong if:** [the evidence that would disprove it] — **watched in:** [beta results / lost-deal notes / churn reasons / a named metric]. Revise this kernel before the next OKR cycle when it appears.

## Parent Kernel (enterprise product-line kernels only)

**Parent:** [link to the company kernel]
**Why this line needs its own:** [the different crux it faces]
**Consistent with:** [confirm nothing here is something the parent rules out]
```
