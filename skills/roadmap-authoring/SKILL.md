---
name: roadmap-authoring
description: >
  Teaches how to write a product roadmap during Strategy as a statement of
  intent and direction (Lombardo et al.), not a release plan: rows are themes
  (customer problems, not capability categories or features), each naming the
  Key Result it serves, with candidate solutions in Now only, stage, confidence
  and dependencies, across broad Now / Next / Later timeframes, under a vision
  line and a required disclaimer. Covers testing the Now themes for coherence and
  sequencing the weakest link first (Rumelt), citing the guiding policy for every
  exclusion, a named prioritisation framework by scale, pre-wiring the review,
  roadmap vs release plan vs backlog, revision history and its triggers, and
  sizing by scale profile. Use when writing or reviewing a roadmap, rejecting a
  feature-and-date list, or checking what the roadmap reads. Used by the
  product-strategist agent after the OKR set; it reads the OKRs and the strategy
  kernel and never feeds them.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, roadmap, themes, sequencing, okr, prioritisation]
produces: strategic-roadmap
domain: strategy
status: stable
related: [okr-authoring, strategy-kernel, vision-statement, gtm-strategy, stakeholder-mapping, story-mapping, moscow-prioritization, nfr-specification, glossary-management]
sources:
  - research/product-strategy-and-gtm/product-roadmaps-relaunched-lombardo.md
  - research/product-strategy-and-gtm/good-strategy-bad-strategy-rumelt.md
  - research/product-strategy-and-gtm/measure-what-matters-doerr.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/product-management-in-practice-lemay.md
  - research/requirements-and-user-stories/user-story-mapping-patton-economy.md
  - research/storytelling-and-narrative/the-best-story-wins.md
---

# Roadmap Authoring

## Purpose

A roadmap is **a statement of intent and direction**: which customer problems the product will work on, in what order, toward which objectives, and how sure we are. The framing is Lombardo, McCarthy, Ryan and Connors' (*Product Roadmaps Relaunched*). It is a promise about direction and value, not about features on days. Cagan (*Inspired*) names the feature-and-date roadmap as the structural cause of feature teams: it decides the solution before discovery. A roadmap that lists features with dates is a release plan in the wrong place.

It is the last Strategy artifact, and it **reads; it never feeds**:

```
Vision ──► Strategy kernel ──► OKR set ──► Roadmap
(North Star) (crux, guiding    (Objectives,   (themes that serve the KRs,
              policy, actions)  KRs, Initiatives) sequenced and tested for coherence)
```

**Inputs: the vision, the strategy kernel and the OKR set** (plus the GTM strategy where it exists). If no OKR set exists, stop and write it first (`okr-authoring`); a roadmap that invents its own goals is goals-as-strategy one level down. Roadmap items are the OKR set's **Initiatives**: bets on how to move a Key Result, free to change while the KR stays fixed (Doerr, *Measure What Matters*). In Rumelt's terms (*Good Strategy / Bad Strategy*) the roadmap sequences the kernel's **coherent actions**.

**The one feedback loop.** If no plausible theme or Initiative could move a KR, do not invent a goal or quietly drop the KR: flag it back to `okr-authoring` for recalibration. That is a check, not an input.

The vision owns the North Star; the roadmap names it in the vision line and never defines its own.

---

## Roadmap, release plan, backlog

| | **Roadmap** (this skill) | **Release plan** | **Backlog** |
|---|---|---|---|
| Answers | *Why*, and *which problems in what order* | *Which solutions ship when* | *What work items carry out the near term* |
| Timeframe | Broad: Now / Next / Later | Dated | The next few iterations |
| Audience | Everyone, from the product owner to customers | The delivery team | The delivery team |
| Changes | At named triggers (below) | Often | Continuously |
| In this plugin | `strategy/roadmap.md` | Later, from the Now horizon and the story map's release slices (`story-mapping`, `moscow-prioritization`) | Ideate's epics and stories |

The roadmap feeds the release plan; it is never generated from one. **No date appears past Now**, except a date a **committed** OKR already carries (a contract or regulation), marked as such.

---

## The five primary components (every roadmap, every scale)

Lombardo et al.'s primary components. A roadmap missing any one fails.

1. **Vision line**: one line pointing at the vision and its North Star. Not a second vision.
2. **Objectives**: the OKR set's Objectives and KRs the themes serve. Every theme names its KR.
3. **Broad timeframes**: Now / Next / Later (the layout the book credits to Janna Bastow of ProdPad), or quarters near in and halves beyond. The further out, the broader.
4. **Themes**: the rows (next section).
5. **Disclaimer**: a required section, on every audience version, stating the roadmap reflects current understanding and will change, and that confidence describes sequence and scope, not importance.

**Secondary components**, added when they apply: **stage of development** (on every row from standard up; date-free progress: research → discovery → development → beta → released), **confidence** (on every row at every scale in this plugin), **candidate solutions** (Now only), **target customer** (when the GTM strategy names more than one segment), **product areas** (swimlanes, enterprise).

---

## Themes: the row type in every horizon

A **theme** is a customer problem or job, phrased in the customer's words so that **more than one solution could satisfy it**. It is not a capability category ("Compliance Coverage Depth"), not a feature ("Recurring scans and alerts") and not a quality target (a page-load time is an NFR for `nfr-specification`). Test: would a customer recognise this as their problem, and could discovery find a different solution and still satisfy it?

The theme stays the same row as it moves from Later to Now; it gains detail, it is not rewritten. Each row carries:

| Column | Rule |
|---|---|
| **Theme** | The customer problem |
| **Serves** | The KR it moves (`KR1.2`). Next/Later may cite an Objective or an annual Objective. Never "Strategic — …": if no KR fits, write **Guiding policy:** [the clause it carries out], or the row is cut |
| **Candidate solutions** | **Now only**: the OKR set's Initiatives, written as bets ("we believe X will move KR1.2"; LeMay), not commitments. `—` in Next and Later |
| **Stage** | Where the theme stands, instead of a date |
| **Confidence** | High / Medium / Low, decaying with horizon |
| **Dependencies** | Other themes, decisions, third parties, other teams |

A theme and an outcome are both needed: the theme names the problem; the KR says how success is measured. Keep the theme sharp; a vague label is not a theme.

**Confidence bands are this plugin's convention, not the book's.** Lombardo et al. require confidence that falls with distance but give no numbers. The plugin calibrates: **High** (> 80%: problem and solution well understood), **Medium** (50–80%: direction set, solution open), **Low** (< 50%: intent only). Typically Now is High, Next Medium, Later Low; uniform confidence across horizons is a defect.

---

## Sequencing: coherence, weakest link, then the framework

1. **Weakest link first** (Rumelt). If one capability caps the value of everything else (trust in the output, a data boundary, an import that must work), its theme goes first in Now, ahead of "highest value". Improving other links first wastes effort.
2. **Coherence, not just traceability** (Rumelt). For each Now theme ask: does it make another Now theme easier or more valuable, or pull effort from one? Record what each reinforces. A theme that links to a KR but reinforces nothing is a cut candidate (entropy at work).
3. **A named prioritisation framework** for everything else, stated in the artifact's "How this was prioritised" line, so stakeholders argue about inputs, not outcomes. Default: **critical path** at lean; a **value / effort / confidence scorecard** at standard and enterprise, scores shown; **Kano** when the question is "which needs are table stakes?". Read `./references/prioritisation-frameworks.md` when choosing or scoring. This is strategic-theme ordering; MoSCoW is release scope in Ideate (`moscow-prioritization`).
4. **Later themes may name the next segment they unlock** (Moore's bowling alley, *Crossing the Chasm*): a theme justified because it completes the whole product for the segment adjacent to the beachhead, using the target-customer column.

---

## Saying no: "Not On This Roadmap"

Every declined request and tempting direction goes here, and **every entry cites the guiding-policy clause (or the diagnosis) that excludes it**, not a free-floating reason. This is Lombardo's "saying no" practice with Rumelt's rule that exclusions derive from the policy. It keeps Later from becoming landfill. An exclusion with no policy reason is a decision nobody can review.

---

## Review, views and revision

**Pre-wire before review** (the book's nemawashi and shuttle diplomacy; alignment, not consensus). **Lean:** before asking for approval, list the decisions the product owner is most likely to push back on, with the reason for each. **Standard / enterprise:** read the `stakeholder-mapping` engagement plan and record who was consulted, one at a time, and in what order, before the group review. Read `./references/alignment-and-views.md` for the technique and the audience views.

**Revision history** is a required table (date, what moved, what was dropped, the learning). Revise at these **named triggers**: each OKR cycle; when discovery results arrive; when the strategy kernel is revised; when the Ideate story map exists (its release slices are the first concrete test of the Now horizon, per Patton); and when a KR proves unmovable (flag it to `okr-authoring`).

**Not a story.** *The Best Story Wins* is explicit that story-arc framing does not fit a roadmap: a resolved narrative manufactures certainty about Later. Keep the roadmap a table.

---

## Scale

Required at every profile (`phase-requirements.json`: "lean: one page"). The primary components never change; the secondary ones grow.

| Profile | Shape |
|---|---|
| **lean** (solo, one service) | **One page.** Now / Next / Later; **two to five themes in total**, each tied to the single lean Objective's KRs; vision line, disclaimer, critical-path prioritisation; confidence on every row; no audience views, no product areas, target customer implicit; objections pre-listed; revised each OKR cycle |
| **standard** | Now / Next / Later, or near-term quarters with halves beyond; themes tied to specific KRs; **stage and confidence on every row**; target customer when GTM names more than one segment; a value / effort / confidence scorecard; **internal and external views**; review pre-wired with the stakeholder map; monthly near-term review |
| **enterprise** | **Product-area swimlanes** (several teams or lines on one roadmap, or a portfolio view above per-line roadmaps); cross-team dependencies explicit; themes tied to aligned OKRs at more than one level; stakeholder alignment recorded (who, in what order); views for executives, sales, engineering and customers; contractual or regulatory dates allowed **only as committed items**, matching committed OKRs |

---

## How to Write One

1. **Read the inputs**: the vision (North Star), the strategy kernel (crux, guiding policy, rules-out list, coherent actions) and the OKR set (Objectives, KRs, candidate Initiatives); the GTM strategy if it exists. No OKR set: stop.
2. **Write the vision line and the objectives block** from those artifacts, verbatim; invent nothing.
3. **Draft themes as customer problems** before any solution, one or more per KR. Rewrite every feature or capability category into the problem it answers; the feature becomes a Now candidate solution or is dropped.
4. **Check every KR is served.** A KR no theme can move goes back to `okr-authoring`, recorded in the revision history.
5. **Sequence**: weakest link, coherence test, then the named framework; place themes in broad timeframes; set stage, confidence and dependencies.
6. **Add candidate solutions to Now only**, from the OKR set's Initiatives, as bets.
7. **Write "Not On This Roadmap"** from the kernel's rules-out list and every declined request, each citing the guiding-policy clause.
8. **Add the secondary components** the profile calls for (target customer, product areas, views), then **pre-wire the review**.
9. **Validate** with `./resources/roadmap-health-check.md`; every row is a hard stop.
10. **Produce the artifact** from `./templates/strategic-roadmap-template.md` at `strategy/roadmap.md`, with the revision history started.

**Examples, simple to complex:**
- A lean internal tool on one page, three themes under one Objective: read `./examples/01-lean-one-page.md`.
- A standard B2B SaaS roadmap rewritten from a feature-and-date list, with a scorecard, a committed date and two views: read `./examples/02-standard-feature-list-rewrite.md`.
- An enterprise multi-tenant platform with product-area swimlanes, a weakest-link Now, a bowling-alley Later and policy-cited exclusions: read `./examples/03-enterprise-swimlanes.md`.

---

## Anti-Patterns

| Anti-pattern | Example | Fix |
|---|---|---|
| **Release plan in disguise** (Cagan; Lombardo) | "Q3: Drive connector — Aug 15" | Theme + KR; dates go to the release plan |
| **Roadmap before OKRs** | Themes with their own invented goals | Write the OKR set first; themes serve its KRs |
| **Capability-category theme** | "Multi-Framework Intelligence" | The customer problem it answers |
| **Solution-first theme** (Lombardo) | A theme only one feature can satisfy | Name the problem; the feature is a candidate solution |
| **"Strategic —" link** (Rumelt) | "OKR link: Strategic — expands TAM" | A KR, or "Guiding policy: [clause]", or cut it |
| **Unreasoned exclusion** | "Not on roadmap: DLP" | Cite the guiding-policy clause that rules it out |
| **Peanut-butter spread** (Rumelt) | Effort spread evenly across every theme | Concentrate Now on the weakest link and themes that reinforce it |
| **Entropy** (Rumelt) | Themes added over time that serve no current policy | Prune to the policy at each revision |
| **Uniform confidence** | Every row High, including Later | Confidence decays with horizon |
| **Later as landfill** | Every request parked in Later | Decide; move the no to "Not On This Roadmap" |
| **Sales-deck roadmap** (Lombardo) | Themes turned into dated promises to close a deal | External view: themes and stages, no dates, disclaimer |
| **Consensus hunt** (Lombardo) | Re-litigating every item with every stakeholder | Seek alignment on direction, pre-wired |
| **Silent re-planning** | The roadmap changed with no record | Revision history at named triggers |
| **Second North Star** | A roadmap "north star" section | The vision's, in the vision line |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Inputs | Reads the vision, kernel and OKR set; feeds none of them | Written before the OKRs; invents goals |
| Primary components | Vision line, objectives, broad timeframes, themes, disclaimer all present | Any missing; disclaimer as a footnote |
| Theme is a problem | More than one solution could satisfy each theme | Features or capability categories as rows |
| Traceable | Each theme names a KR (or a guiding-policy clause) | "Strategic —" or no link |
| Coherent | Now themes reinforce each other; weakest link first | A traceable but unrelated pile |
| Prioritisation stated | The framework named (and scored at standard+) | "Sequenced by value" with no method |
| Confidence | On every row, decaying with horizon | Missing or uniform |
| No dates past Now | Only committed-OKR dates, marked | Dated features in Next or Later |
| Exclusions | Each cites the guiding policy | No reasons, or reasons tied to nothing |
| Revision recorded | History table and named triggers | None |
| Size fits the profile | Matches the Scale table | Lean on three pages; enterprise with no swimlanes |

Use the canonical terms from `glossary-management`: **Product Roadmap**, **Theme**, **Roadmap Disclaimer**, **Stage of Development**, **Release Plan**, **Initiative**, **Key Result**, **Guiding Policy**, **Coherent Actions**, **North Star Metric**.
