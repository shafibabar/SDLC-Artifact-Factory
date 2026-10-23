---
name: competitive-analysis
description: >
  Teaches how to write a competitive analysis that starts from the competitive
  alternatives (what the customer would do without the product, including doing
  nothing, a spreadsheet or "no decision"), takes its comparison criteria and
  positioning-map axes from the buyer's evaluation criteria rather than from where
  the product looks good, labels every vendor claim with its source and date or as
  "unverified (model knowledge)", scores substitutes honestly, filters
  differentiation points as real, valued and defensible, and keeps a win/loss log.
  Use when listing competitors or alternatives, building a capability matrix or
  positioning map, running a competitive SWOT, checking a matrix for flattery,
  recording why a trial or deal was won or lost, or handing the product's
  advantage to the strategy kernel. Used by the product-strategist agent in the
  Strategy phase (/sdlc-strategy), after the stakeholder map and before the
  strategy kernel; required at standard and enterprise, optional at lean.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, competitive-analysis, competitive-alternatives, positioning, differentiation, win-loss]
produces: competitive-analysis
domain: strategy
status: stable
related: [strategy-kernel, business-model-canvas, gtm-strategy, vision-statement, stakeholder-mapping, jtbd-analysis, requirements-analysis, glossary-management]
sources:
  - research/product-strategy-and-gtm/obviously-awesome-dunford.md
  - research/product-strategy-and-gtm/loved-lauchengco.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/competing-against-luck-christensen.md
  - research/product-strategy-and-gtm/challenger-customer-adamson-dixon.md
---

# Competitive Analysis

## Purpose

A competitive analysis answers one question: **what will the buyer compare us against, on what criteria, and where are we genuinely and defensibly better?** It is evidence for the strategy, not a brochure. Its most important reader is the **strategy kernel**, whose guiding policy must rely on an advantage this analysis shows against the *real* alternatives. An analysis built to make the product look good hands the kernel an advantage that does not exist.

Three ideas shape it. Dunford (*Obviously Awesome*) starts positioning from the **competitive alternatives**, what the customer would do if the product did not exist, and keeps only attributes that are both real and valued. Christensen et al. (*Competing Against Luck*) give the reason: every hire is also a firing, so the competition is whatever gets fired, often a spreadsheet, a consultant or nothing at all (**non-consumption**). Adamson and Dixon (*The Challenger Customer*) add that in B2B buying groups the commonest loss is not to a rival but to **no decision**. Lauchengco (*Loved*) closes the loop: claims of difference are hypotheses until **win/loss** outcomes confirm them.

## Where It Sits

```
Vision ─► Stakeholder map ─► COMPETITIVE ANALYSIS ─► Strategy kernel ─► Canvas ─► GTM ─► OKRs ─► Roadmap
```

| Reads | What it takes |
|---|---|
| `vision-statement` | The protagonist and the job: whose alternatives to list |
| `stakeholder-mapping` | The buying committee: whose evaluation criteria count, and who defends the status quo |
| The user | Evidence: pricing pages, demo notes, lost-deal notes, analyst reports. Agents here have no web research, so the user is the only source of verified vendor facts |

| Feeds | What it gives |
|---|---|
| `strategy-kernel` | The **advantage hand-off**: the differentiation points that survived all three filters, with their evidence status. The guiding policy's "relies on" cites one of them; the diagnosis may name an alternative (often doing nothing) as part of the challenge |
| `business-model-canvas` | The alternatives become the Lean Canvas's Existing Alternatives and the "unlike…" of each value proposition. Only a *defensible* point can become the Unfair Advantage (it already passed the copy-or-buy filter here) |
| `gtm-strategy` | The one list of competitive alternatives and the surviving unique attributes that positioning starts from, plus the win/loss log behind its **Positioning Refresh Trigger**. GTM chooses the market category and writes the positioning; it does not build a second alternatives list |
| `requirements-analysis` | Table-stakes capabilities: criteria where every alternative is strong and the buyer will not consider a product without them |

**Ownership:** this skill owns the competitive alternatives list and the win/loss log. Other artifacts cite them.

## Scale

`phase-requirements.json` makes this artifact **optional at lean** and **required at standard and enterprise**.

| Profile | Shape |
|---|---|
| **lean** (if written) | Half a page: the alternatives (doing nothing first), 3–5 buyer criteria, a small matrix with evidence labels, at most two differentiation points. No positioning map, no SWOT, no risk table. Win/loss only if anyone can actually choose an alternative |
| **standard** | The full artifact: alternatives, weighted criteria, evidence register, matrix, positioning map on the buyer's two heaviest criteria, competitive SWOT, 2–3 differentiation points, risks and a win/loss log (empty until the first trial or deal closes, with the date it starts) |
| **enterprise** | Everything in standard, plus: criteria **per buying-committee role** (and per segment where segments buy differently); a **category lens** showing how the criteria change under each candidate market category; composite cells decomposed into the **whole product** (Moore); future entrants including platforms that could bundle the capability; the win/loss log mandatory once the closed beta has run |

## The Rules

**1. Alternatives first, doing nothing first among them.** Before naming a single vendor, write down what the customer would do if the product did not exist: tolerate the pain, a manual workaround, a spreadsheet, a consultant, an in-house script, an adjacent tool. In B2B, add **no decision**: the buying group fails to agree and stays with the status quo. Then add direct and indirect competitors and future entrants. Rate the alternatives on the same criteria as the vendors. Taxonomy and prompts: `./references/alternatives-and-criteria.md`.

**2. The buyer's criteria come before any plotting.** List the criteria the buyer actually uses to choose, in the buyer's words, weighted, *before* scoring anyone. Draw them from interviews and lost-deal notes, the stakeholder map's buying-committee roles, and the criteria the market category the buyer puts you in brings with it (Dunford). The positioning map's axes are the **two heaviest buyer criteria**, never the two dimensions where the product sits alone. If the product is not in open space on the buyer's axes, that is a finding for the kernel, not a reason to change the axes.

**3. Every vendor claim carries its evidence.** Each claim about a competitor (a capability, a price, a deployment model, a customer count) gets a **source and date**, or the label **`unverified (model knowledge)`**. No claim is silently presented as fact. Ask the user for the evidence that would verify the claims a differentiation point depends on, and list what you asked for in the artifact. A differentiation point that rests on an unverified claim is a **hypothesis**, and the kernel is told so. This holds for a partial answer too: a matrix asked for in chat still carries an evidence ID in every vendor cell and the register behind it. A sentence saying "the features are from memory" does not label anything. Labels, what to ask for, and how to handle "as of" dates: `./references/evidence-and-win-loss.md`.

**4. Score honestly, including the substitutes.** A spreadsheet maintained by a consultant may match the product on privacy and expertise; say so. A matrix where every alternative scores ✗ on every row is a **flattering matrix**: either the criteria were chosen to favour the product or the scoring is dishonest. Where one cell hides several things (a "fit for small firms" cell), decompose it into the whole product: core capability, integrations, onboarding and support, proof (references, certifications) (Moore).

**5. Differentiation points pass three filters.** Each point is **real** (the true alternatives lack it, on evidence), **valued** (it maps to a heavy buyer criterion) and **defensible** (a funded competitor could not copy or buy it within the planning horizon: being first, features, speed and "a great team" fail). Dunford's first two filters are the core; the third is what the kernel and the canvas's Unfair Advantage need. Points that fail "defensible" can still feed positioning; they cannot be the kernel's advantage.

**6. Look back as well as forward.** Competitive risks look forward; the **win/loss log** looks back (Lauchengco). Each closed trial, pilot or deal gets a row: the alternative it was weighed against, the outcome (won, lost, no decision), the buyer's stated reason, and which differentiation point it confirms or contradicts. A contradicting outcome fires `gtm-strategy`'s Positioning Refresh Trigger and is evidence for the kernel's review trigger.

## How to Build One

1. **Read the inputs** and ask the user for whatever evidence they hold (rule 3). Do not wait for it; label what you cannot verify.
2. **List the competitive alternatives** (rule 1). Doing nothing first; no decision for any B2B buying group.
3. **Write the buyer's evaluation criteria** (rule 2), weighted, with where each came from. At enterprise, per committee role, and the category lens.
4. **Build the evidence register and the capability matrix.** Every rating about an alternative cites an evidence ID whose row has a source and date or the `unverified (model knowledge)` label; a bare rating is a defect, and a cell with no claim behind it is `?`. Ratings: ✓ strong · ~ partial · ✗ absent · ? unknown.
5. **(standard+) Draw the positioning map** on the two heaviest criteria, and say honestly who shares the product's space.
6. **(standard+) Run the competitive SWOT**: strengths and weaknesses on criteria the buyer values; opportunities = needs no alternative serves; threats = who is moving toward the product's position, including future entrants.
7. **Filter the differentiation points** (rule 5) and record each one's evidence status.
8. **(standard+) Record competitive risks and open the win/loss log** (rule 6).
9. **Write the hand-off to the strategy kernel**: the surviving points, the strongest alternative (often doing nothing), and what would show the advantage is not real.
10. **Validate** against `./resources/competitive-analysis-checklist.md`, then produce the artifact from `./templates/competitive-analysis.md` at `strategy/competitive-analysis.md`.

**Examples, simple to complex:**
- A lean internal tool whose only real alternatives are the chat thread and doing nothing: `./examples/01-lean-lunch-tracker.md`.
- A standard B2B SaaS product whose first draft was a flattering matrix, rebuilt from the buyer's criteria with honest substitute scores and evidence labels: `./examples/02-standard-ledgerline-flattering-matrix.md`.
- An enterprise multi-tenant platform entering a crowded category: the category lens changes the axes, per-role criteria, a hyperscaler as future entrant, and a win/loss log after the closed beta: `./examples/03-enterprise-platform-crowded-category.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Alternatives first | Doing nothing (and no decision in B2B) listed and scored like any vendor | Only named vendors; substitutes as one optional row |
| Buyer's criteria | Weighted, sourced, written before scoring; map axes are the two heaviest | Axes picked where the product sits alone; generic "price, support, features" |
| Evidence | Every vendor claim has a source and date or `unverified (model knowledge)`; evidence requested from the user is listed | Confident vendor facts and prices from memory, or one blanket disclaimer at the top |
| Honest scoring | Substitutes score where they are strong; composite cells decomposed | Every alternative ✗ everywhere |
| Differentiation | 2–3 points (lean: ≤2), each real, valued, defensible, with evidence status | "Better UX", "AI-powered", "first mover" |
| Looks back | (standard+) A win/loss log with outcome, alternative, reason, point confirmed or contradicted | Only forward-looking risks |
| Hand-off | Names the advantage candidates for the kernel and their evidence status | The kernel has to guess which point to rely on |
| Shape and scale | Frontmatter with `name`, `version`, `phase`, `owner`, `created`, `summary`; matches the Scale table | Missing `summary`; lean padded with SWOT and map |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **The flattering matrix** | Criteria chosen where the product wins, or every alternative zeroed. The kernel inherits an advantage the buyer never sees |
| **Axes of convenience** | "AI-native × modern UI" because nobody else is there; empty space on criteria nobody buys on is not a position |
| **Memory as research** | Prices and feature claims recalled by the model, written as fact. Wrong numbers then reach positioning and pricing |
| **No substitutes, no status quo** | Ignores the spreadsheet, the consultant and no decision: the alternatives most deals are actually lost to |
| **Two alternatives lists** | GTM rebuilds its own list; the two drift. This artifact owns the list |
| **Imitation as strategy** | The matrix shows the product following every competitor and leading on nothing |
| **Frozen analysis** | Written once; a lost deal that contradicts a differentiation point changes nothing |

Use canonical terms from `glossary-management`: **Competitive Alternative**, **Win/Loss Log**, **Whole Product**, **Strategy Kernel**, **Unfair Advantage**.
