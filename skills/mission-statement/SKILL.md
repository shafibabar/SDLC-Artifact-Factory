---
name: mission-statement
description: >
  Writing or reviewing a product mission statement — the present-tense declaration
  of what the product does today, for whom, and to what end, distinct from the
  future-tense vision. Covers the vision-vs-mission distinction, the required
  components (what we do / for whom / to what end), the "We [do X] for [user] so
  that [outcome]" format, mission as a scope constraint that makes it easy to say
  no, the quality criteria (present tense, single active verb, named beneficiary,
  stated outcome, vision alignment, <=50 words), the generic-aspirational-fluff
  anti-patterns, and how the mission anchors okr-authoring, product strategy, and
  the gtm positioning statement. Triggers on mission statement, mission vs vision,
  present-tense purpose, scope boundary, north star, what we do for whom.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, mission, vision, product-strategy, north-star]
produces: mission-statement
domain: strategy
status: stable
related: [vision-statement, okr-authoring, gtm-strategy, business-model-canvas]
---

# Mission Statement

## Purpose

A mission statement answers: **what do we do, for whom, and to what end — right now?**

Where the vision describes the future state, the mission describes the present-day
work that creates it. The mission changes when the *approach* changes; the vision
changes only when the *fundamental purpose* changes.

The mission's job is to act as a **scope constraint**. When a feature, partnership,
or initiative does not serve the mission, it is out of scope regardless of how
attractive it appears. A mission you cannot use to say "no" is not doing its job.

The full artifact template, the expanded quality checklist with diagnostic tests,
and four worked examples (including a complete worked mission for this repo's
data-estate / compliance product) live in
`references/mission-examples-and-template.md`. This body carries the distinctions,
criteria, and anti-patterns you reason with; the reference carries the material
you copy from.

---

## Vision vs Mission — the critical distinction

| Dimension | Vision | Mission |
|---|---|---|
| Tense | Future | Present |
| Horizon | 3–5+ years | Current product stage |
| Question | Where are we going? | What do we do to get there? |
| Stability | Rarely changes | Evolves as strategy evolves |
| Scope effect | Defines purpose | Constrains scope |

**The most common mistake** is writing a mission that is actually a vision
(aspirational, future-tense, untestable today) — or a vision that is actually a
mission (describes current work rather than a future destination). Diagnostic:
prepend "right now, today" to the sentence. If it is only true in the future, it
is a vision, not a mission. (See Example 2 in the reference.)

Vision and mission are authored as a **pair**, vision first. The mission is the
vision's present-day execution path — see `vision-statement`.

---

## Required components

Every mission statement contains three elements:

| Component | Question | Guidance |
|---|---|---|
| **What we do** | The primary action the product performs. | Specific enough to *exclude* activities you will not do. One primary verb, not a menu. |
| **For whom** | The primary beneficiary. | The same target user named in the vision, possibly narrower. Never "users"/"companies". |
| **To what end** | The outcome the beneficiary experiences. | What the user can now *do* or *know* — not what the product outputs. Must connect to the vision. |

**Format:**

```
We [verb: what we do] for [target user] so that [outcome the user experiences].
```

The connecting phrase `so that` is load-bearing — it forces the sentence to end on
the beneficiary's outcome, not the product's activity. The reference gives a second
equivalent action-first format and the reasoning for each.

---

## How to produce one

1. **Start from the vision.** If the mission does not connect to the vision, one of
   them is wrong.
2. **Define the primary action.** One active verb — `maps`, `classifies`,
   `catalogs`, `monitors`, `reconciles`. Avoid `enable`, `help`, `provide`,
   `support` as the primary verb.
3. **Name the beneficiary precisely.** Reuse the vision's target user; if the
   vision covers several, the mission names the primary one.
4. **State the outcome the beneficiary experiences.** Test with "so that they
   can…".
5. **Check the scope constraint.** Can you now write a 3–5 item out-of-scope list?
   If not, the mission is too broad.
6. **Check vision alignment.** If you achieve this mission at scale over years, do
   you get the vision? If not, there is a misalignment.

The reference walks this exact sequence end-to-end for the data-estate product.

---

## Quality criteria (in brief)

| Criterion | Pass | Fail |
|---|---|---|
| Present tense | Describes what the product does today | Describes what it *will* do |
| Single active verb | One specific action verb | A list of verbs, or `enable`/`help`/`support` as the main verb |
| Beneficiary named | A specific user group | Generic ("users", "companies", "people") |
| Outcome stated | What the user can do or know | Product features/outputs only |
| Scope constraint | Reading it makes scope decisions easier | So broad any feature qualifies |
| Vision alignment | Executing it moves toward the vision | Could succeed while the vision stays unmet |
| Length | 1–3 sentences, <= 50 words | Over 50 words or disconnected clauses |

Each criterion has a concrete diagnostic test (the single-verb test, the
"so that they can…" reversal, the competitor test for the beneficiary word, the
out-of-scope-list test) — see the reference for the full checklist and how to
apply each one during review.

---

## How the mission anchors the rest of Strategy

- **okr-authoring** — the mission's stated outcome is the source of the top-level
  Objective. Key Results must measure movement of *that outcome*, never feature
  delivery. A KR moving something the mission doesn't name signals a drift.
- **Product strategy / roadmap** — the mission is the standing scope filter every
  strategic bet is checked against. Consistent with Cagan's outcome-over-output
  stance (*Inspired*): the mission names an outcome, and strategy sequences the
  bets that move it — it does not pre-decide features.
- **gtm-strategy** — the positioning statement compresses the mission's verb,
  beneficiary, and differentiator into one sentence. Per Dunford (*Obviously
  Awesome*), that sentence is a *compression* of fuller positioning work; the
  mission supplies its outcome and scope.
- **business-model-canvas** — the mission's beneficiary and outcome must match the
  canvas's Customer Segments and Value Propositions blocks.

---

## Anti-patterns

**Feature list masquerading as mission** — "provide scanning, classification,
reporting, dashboards, and alerts." Lists capabilities, states no outcome; fails
the single-verb test.

**Indistinguishable from vision** — "make every organisation's data estate fully
transparent and compliant." Aspirational, future-tense: a vision, not a mission.

**No scope constraint (generic aspirational fluff)** — "help companies manage
their data better." Every data product on the planet could claim it; you cannot
derive an out-of-scope list from it.

**Internal focus** — "build the best data-estate platform using cutting-edge AI."
Describes internal ambition and technology, not user benefit — and (per Dunford)
trend-led framing that ages into generic noise.

The reference shows the strong rewrite for each of these, with the reasoning.
