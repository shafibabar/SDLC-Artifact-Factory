# OKR Set — Artifact Template

Self-contained. Copy everything inside the fence into `artifacts/<product>/strategy/okrs.md` and replace every `[bracketed]` value. At **lean**, keep one Objective with about three KRs, one or two health metrics, and delete the "Aligns to" lines. At **standard**, repeat the Objective block up to three times. At **enterprise**, write one file per level (company, product line, team), with 3–5 Objectives at company and product-line level (a team may hold fewer), and fill the "Aligns to" and "Depends on" lines. The check-in log and grading table stay empty until the cycle runs.

Starting confidence by type: **aspirational about 50%**, **committed 90% or more**. Expected grade by type: aspirational about 0.7, committed 1.0. Confidence is the weekly forecast; the grade is the end-of-cycle measurement.

---

```markdown
---
name: okr-set
product: [product name]
cycle: [Q1 2027]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the cycle's Objectives in brief, e.g. "Q1 2027 OKRs: every regular orders lunch through the chat command without chasing (one aspirational Objective, three KRs)."]
owner: product-strategist
traces_to: [strategy/vision-statement.md; strategy/strategy-kernel.md]
---

# OKR Set — [Cycle]

## Strategy this set serves

**Crux:** [from the strategy kernel]
**Guiding policy:** [one line from the kernel]
**North Star (from the vision):** [the vision's metric, as the vision states it] — this cycle moves it by [which part, in words]
**Levels:** [solo: product and company OKRs are one set] / [enterprise: this is the <company | line | team> set; parent set: <link>]

---

## Objective 1 — [Qualitative, proximate, no numbers]

**Type:** [committed | aspirational]
**From the kernel's proximate objective:** "[the hand-off line it turns into an Objective]"
**Aligns to:** [enterprise only — the higher-level Objective it advances]
**Depends on:** [enterprise only — teams whose work this needs, and the matching KR or Initiative they hold]

| KR | Metric | Baseline | Target | Dir | Owner | Start confidence |
|---|---|---|---|---|---|---|
| KR1.1 | [behaviour change, as a rate where possible] | [measured value / n/a (pre-launch) / not yet measured — first reading by YYYY-MM-DD] | [value] | ↑/↓ | [one owner] | [50% or ≥90%] |
| KR1.2 | | | | | | |
| KR1.3 | | | | | | |

**We believe** [Initiative] **will move** [KR], **and we will know when** [signal].

**Candidate Initiatives** (bets on how to move the KRs; the roadmap sequences them; they may change mid-cycle):
- [Initiative] → KR1.1
- [Initiative] → KR1.2

---

## Health Metrics (must not degrade while we pursue this set)

| Metric | Healthy range | Status |
|---|---|---|
| [e.g. support contacts per week] | [≤ 5] | green |
| [paired counter-metric for a volume KR] | [range] | green |

---

## Weekly Check-in Log

One entry per week (Wodtke's four-square: priorities, KR confidence, next weeks, health). Append; never rewrite earlier entries.

| Week of | KR | Confidence | Note (priorities this week, outlook, any health metric not green) |
|---|---|---|---|
| [YYYY-MM-DD] | KR1.1 | [%] | [note] |

---

## Grading (quarter-end)

| KR | Type | Expected | Final value | Grade | Committed miss: what happened and recovery plan |
|---|---|---|---|---|---|
| KR1.1 | [type] | [0.7 or 1.0] | | | |

| Objective | Grade (avg) | What we learned |
|---|---|---|
| O1 | | |
```
