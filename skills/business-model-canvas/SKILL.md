---
name: business-model-canvas
description: >
  Teaches how to build, review or revise a business model canvas: the nine-block
  Business Model Canvas (Osterwalder) or the Lean Canvas (Maurya: Problem,
  Solution, Unique Value Proposition, Key Metrics, Unfair Advantage), chosen by
  evidence state, with a Value Proposition Canvas per segment (jobs, pains, gains,
  pain relievers, gain creators, fit), business model patterns (freemium,
  multi-sided platform, long tail, unbundling, open), a per-block evidence status,
  risk ranking with testable hypotheses, and a coherence check for either variant.
  Use when writing a business model canvas or lean canvas, checking whether the
  blocks fit, deciding Lean Canvas vs full canvas, or asking what Revenue Streams
  should state. Used by the product-strategist agent in the Strategy phase
  (/sdlc-strategy), after the strategy kernel and before the GTM strategy;
  required at every profile (a Lean Canvas at lean).
version: 3.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, business-model, canvas, lean-canvas, value-proposition, value-proposition-canvas, discovery]
produces: business-model-canvas
domain: strategy
status: stable
related: [strategy-kernel, gtm-strategy, competitive-analysis, vision-statement, jtbd-analysis, user-persona, impact-mapping, beta-program-design, okr-authoring, glossary-management]
sources:
  - research/product-strategy-and-gtm/business-model-generation-osterwalder.md
  - research/product-strategy-and-gtm/running-lean-maurya.md
  - research/product-strategy-and-gtm/monetizing-innovation-ramanujam.md
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
  - research/product-strategy-and-gtm/lean-product-playbook-olsen.md
  - research/product-strategy-and-gtm/obviously-awesome-dunford.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/human-ai-collaboration/unleash-creativity-with-ai-bier.md
---

# Business Model Canvas

## Purpose

A business model canvas puts a whole business on one page: who it serves, what value it offers them, how it reaches them, how it earns, and what it costs (Osterwalder and Pigneur, *Business Model Generation*). It answers one question: **do the blocks fit together into a business that can work, and which part of it is most likely to be wrong?** The value is the fit between the blocks, not the nine lists.

Every block starts as a guess. Blank (*The Four Steps to the Epiphany*) treats the canvas as the list of hypotheses that Customer Development then tests, one block at a time, against real customers. So the canvas is never "filled in once": each block carries its **evidence status**, and the riskiest guesses carry the test that would settle them.

## Where the Canvas Sits

```
Vision ─► Stakeholder map ─► Competitive analysis ─► Strategy kernel ─► CANVAS ─► GTM strategy ─► OKRs ─► Roadmap
```

| Reads | What it takes |
|---|---|
| `strategy-kernel` | The guiding policy's **advantage** becomes the Unfair Advantage (or the hard-to-copy Key Resource); a *focus* policy fixes the primary segment. The canvas carries the policy out; it never contradicts what the kernel rules out |
| `vision-statement` | The protagonist and their job: the first draft of the primary segment and its top job |
| `competitive-analysis` | The competitive alternatives (including doing nothing): the Lean Canvas's Existing Alternatives and the "unlike…" end of each value proposition |
| `jtbd-analysis`, `user-persona` | Ranked jobs and pains. Written in Ideate, so on a first pass they do not exist yet: see the Value Proposition Canvas rule below |

| Feeds | What it gives |
|---|---|
| `gtm-strategy` | Segments, value propositions, the charging unit and willingness-to-pay evidence. GTM picks the beachhead and **sets the price**; the canvas never restates it |
| `okr-authoring` | Key Metrics and the riskiest hypotheses, as candidate Key Results for proving the model |
| `beta-program-design` | The top risks and Problem/Solution Fit exit criteria a design-partner programme tests |

---

## Choose the Variant by Evidence, Not by Product

| Use the **Lean Canvas** (Maurya, *Running Lean*) while… | Use the full **Business Model Canvas** once… |
|---|---|
| Problem/Solution Fit is not yet shown: no must-have problem ranked high by early adopters, no solution and price they accept | Those exit criteria are met, and partners, activities and resources can be named from operating evidence |
| Partners, activities and resources would be guesses that look like facts | You are optimising, explaining or extending a model that already earns |

The Lean Canvas keeps the one-page grid and the Customer Segments, Channels, Revenue Streams and Cost Structure blocks. **It does not keep Value Propositions unchanged**: the centre becomes the **Unique Value Proposition** (one clear message about why this is different and worth attention, with an optional "X for Y" High-Level Concept). It drops Key Partnerships, Key Activities, Key Resources and Customer Relationships and adds **Problem** (with Existing Alternatives), **Solution**, **Key Metrics** and **Unfair Advantage**. The pairing is positional on the page; Maurya argues the removals and additions separately. Block-by-block detail: `./references/canvas-blocks.md`.

**Path follows the variant:** a Lean Canvas is written to `strategy/lean-canvas.md`, a full canvas to `strategy/business-model-canvas.md`. On migration the full canvas is written and the Lean Canvas is marked superseded, with the exit criteria that triggered the move.

## Scale

| Profile | Shape |
|---|---|
| **lean** | **Required, as a Lean Canvas** (one page). One segment, so one canvas. No separate Value Proposition Canvas: the Problem block lists the ranked pains and the UVP answers the top one. Evidence status on every block; the top two risks with a test. Revenue may honestly read "not monetised", with the reason. No alternatives step |
| **standard** | Variant by evidence state. A Value Proposition Canvas per segment (and per role where buyer and user differ). **Draft 2–3 alternative canvases** before choosing. Pattern check, full coherence check, top three risks with tests |
| **enterprise** | Usually the full canvas, with every value, channel, relationship and revenue entry tagged to its segment. Everything in standard, plus a profile per B2B stakeholder role, cost-to-serve per segment (and per region where costs differ), and a block-by-block strength / weakness pass with the two or three outside forces most likely to break the model |

One canvas per business model. A product line gets its own canvas only when it has a different model (different segment, charging or cost logic), the same test the strategy kernel uses for line kernels.

---

## The Rules That Shape Every Canvas

**1. Value is mapped, not asserted (the Value Proposition Canvas).** For each segment, the **Customer Profile** lists jobs, **pains ranked by severity** and **gains ranked by relevance**; the **Value Map** lists the products and services, then the **pain relievers** and **gain creators**, each drawn to the specific pain or gain it addresses (Osterwalder et al., *Value Proposition Design*). A reliever that points at no ranked pain is cut. Only the top pains and gains the map actually addresses go into the canvas's value block. A value proposition that names a feature ("real-time scanning") instead of a pain relieved or gain created is not one. Olsen (*The Lean Product Playbook*) gives the same dependency: segment → underserved need → value proposition, and a fault lower down invalidates everything above it.

**Jobs come from `jtbd-analysis`, not from the canvas.** If a JTBD artifact exists, cite its ranked jobs and Opportunity Scores; do not re-gather or rephrase them. On a first Strategy pass it does not exist yet: take the job from the vision's protagonist, mark every job and pain `hypothesis`, and list them as the hand-off `jtbd-analysis` verifies in Ideate. When its ranking arrives, revise the profile to cite it. The canvas never runs interviews; interview discipline lives in `jtbd-analysis`. Profile detail, the three fits and the B2B roles: `./references/value-proposition-canvas.md`.

**2. Every block carries one evidence status.** `hypothesis` (a guess) · `tested` (an experiment ran; result recorded) · `validated` (behavioural evidence: payment, signed pilot, retained usage). Stated interest is weaker than action; a block is `validated` only on what customers *did*. The status belongs to the block, with the entry that is least proven deciding it.

**3. Unknown is allowed; a bare TBD is not.** On a Lean Canvas a block may honestly read **`unknown: tested by <experiment>`**; Maurya treats a blank as information, because it names a risk. A bare `TBD`, an empty block with no test, or a placeholder filler ("great team", "first mover") fails at both variants. On a full canvas every block has a substantive entry, because the variant is only chosen once there is evidence to fill it.

**4. Rank the risk, then test the top of the list.** Tag each uncertain block as **product risk** (Problem, Solution, UVP, Key Metrics: is the problem real, does this solve it), **customer risk** (Segments, Channels: can we reach early adopters) or **market risk** (Revenue, Cost, Unfair Advantage: is it a viable business). Rank by how likely the guess is wrong and how much breaks if it is. For each of the top two (lean) or three, write a falsifiable hypothesis with a success criterion set in advance and a time box. The evidence status says how proven a block is; the risk rank says which unproven block to test next. Formats and exit criteria: `./references/evidence-and-risk.md`.

**5. Revenue states how and on what evidence, not the price list.** The Revenue Streams block names the revenue type (subscription, usage, licensing…), the **charging unit** (the "per what", which should track the value the customer gets), the value anchor, and the **willingness-to-pay evidence**: a range per segment, labelled *stated* (from conversations) or *committed* (pre-order, letter of intent, paid pilot) (Ramanujam and Tacke, *Monetizing Innovation*). Price levels, tiers, fences and price strategy are set in `gtm-strategy`'s Pricing Model; the canvas points there instead of restating them. At lean, where GTM is skipped, one price point with its basis (or "not monetised", with the reason) is enough.

**6. Segments are chosen, not listed.** A segment has a distinct need, channel, relationship and willingness to pay; firmographics describe it so it can be found, they do not define it. "All SMBs" is not a segment. Rank segments and name the primary; the beachhead logic and its criteria belong to `gtm-strategy` (Moore). On a Lean Canvas, **one canvas per segment** whose top problem differs.

**7. Name the pattern if one applies.** Free / freemium / bait-and-hook, multi-sided platform, long tail, unbundling and open models each rearrange the blocks and add checks the generic coherence questions miss (freemium: cost to serve a free user against conversion; multi-sided: a value proposition, channel and revenue entry per side, and which side is subsidised). Read `./references/business-model-patterns.md` when the model gives anything away free, serves two interdependent groups, sells many niche items, outsources a core layer or licenses in or out.

**8. The Unfair Advantage survives the copy-or-buy filter.** Strike anything a funded competitor could copy or buy within the planning horizon: features, being first, speed, passion, "a great team". What is left is usually the kernel's advantage. If nothing survives, the honest Lean Canvas entry is `unknown: tested by…`; on a full canvas it is a recorded finding, not a filler.

---

## How to Build One

1. **Read the inputs** (table above). Note the kernel's advantage and rules-out list; nothing on the canvas may pursue what the kernel ruled out.
2. **Choose the variant** by evidence state.
3. **(standard, enterprise) Draft 2–3 alternative canvases** before choosing. Start each from a different epicentre: offer, customer, resource or finance (Osterwalder), and challenge each block with a "what if…?". Generate before you judge: the first drafts are the most predictable (Bier, *Unleash Your Creativity with AI*). Score them on the coherence check and the top risks; record the rejected ones and why.
4. **Fill in order.** Lean Canvas, in Maurya's order and for his reason (everything derives from a real problem held by a real segment): **Problem and Customer Segments together** (with Existing Alternatives and Early Adopters), then UVP, Solution, Channels, Revenue Streams, Cost Structure, Key Metrics, Unfair Advantage last. Full canvas: Customer Segments, then each segment's Value Proposition Canvas, then the rest of the value side, then the efficiency side and the bottom rail. Per-block lookup lists (segment types, value elements, channel phases, revenue types, partnership types, cost characteristics, AARRR): `./references/canvas-blocks.md`.
5. **Write the value block from the Value Proposition Canvas** (standard, enterprise), never straight from the feature list. Dunford's step helps: group the unique attributes into value themes, then state the theme the segment cares about most.
6. **Mark evidence status, rank the risks, attach the tests** (rules 2–4).
7. **Run the pattern check** if one applies, then the **coherence check** for your variant: `./resources/coherence-check.md`. Revise the block holding any gap; re-run.
8. **Produce the artifact** from `./templates/lean-canvas.md` or `./templates/business-model-canvas.md`.
9. **Keep it live.** Re-validate when a test result lands, at each launch-stage move, and before the next OKR cycle. A failed hypothesis changes its block, and the change is re-checked across the blocks it touches.

**Examples, simple to complex:**
- A lean internal tool with no revenue and an honestly unknown Unfair Advantage: `./examples/01-lean-lunch-tracker.md`.
- A B2B SaaS product: three alternative drafts, a Lean Canvas, then the migration to a full canvas once design partners met the exit criteria: `./examples/02-standard-ledgerline-lean-to-full.md`.
- An enterprise multi-tenant, multi-region platform with two segments (self-serve and sales-led), a freemium tier and per-region cost-to-serve: `./examples/03-enterprise-platform-two-segments.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Variant fits the evidence | Lean Canvas until Problem/Solution Fit exit criteria are met; path matches the variant | A full canvas of guessed partners and resources; a variant chosen by habit |
| Variant-aware completeness | Every block has an entry or `unknown: tested by …` (Lean only) | A bare TBD, an empty block, or filler to avoid a blank |
| Evidence status | Every block carries exactly one: hypothesis / tested / validated | No status, or "validated" on stated interest alone |
| Risks ranked and tested | Top risks typed product / customer / market, each with a falsifiable hypothesis, a success criterion and a time box | "Validate with customers" with no criterion |
| Value mapped | (standard+) Each value entry traces to a ranked pain or gain in its segment's profile; jobs cite `jtbd-analysis` or are marked hypothesis for it | Feature lists; jobs invented and never handed on |
| Revenue grounded | Revenue type, charging unit, value anchor, WTP evidence labelled stated / committed; price set in GTM | Tier prices restated in the canvas; no WTP evidence |
| Coherent | The coherence check for the variant passes, including the pattern's checks | Nine lists that each look complete |
| Alternatives | (standard+) 2–3 drafted, the choice and rejections recorded | One canvas, written straight through |
| Traceable | Names the vision and kernel it serves; carries the kernel's advantage | Free-standing; contradicts the kernel's rules-out |
| Scale fits | Matches the Scale table | A lean canvas padded with a VPC and alternatives; an enterprise canvas with one blended segment |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Nine unconnected lists** | Each block looks finished while the flows between them contradict |
| **Feature-first value** | Names what the product does, not the pain relieved or gain created |
| **Canvas as a plan** | Filled once and filed; blocks never marked as guesses, so no test is ever run (Blank) |
| **Full canvas before fit** | Projects certainty into partners, activities and relationships nobody can know yet |
| **"Value Propositions, unchanged" on a Lean Canvas** | The centre is the Unique Value Proposition: one message, not a list of benefits |
| **Filler to pass "no TBD"** | "First mover" or "great team" in Unfair Advantage hides the real finding: no advantage yet |
| **Price list in the canvas** | Two homes for one decision; GTM's Pricing Model owns levels and tiers |
| **Blended segment** | One value proposition for groups with different needs serves none of them well |
| **Re-gathered jobs** | A second, divergent list of jobs beside `jtbd-analysis`'s ranked one |
| **Aspirational partnerships** | Only partners that exist or can realistically be signed in the planning horizon |

Use canonical terms from `glossary-management`: **Business Model Canvas**, **Lean Canvas**, **Value Proposition Canvas**, **Unique Value Proposition**, **Unfair Advantage**, **Evidence Status**, **Willingness to Pay**, **Problem/Solution Fit**.
